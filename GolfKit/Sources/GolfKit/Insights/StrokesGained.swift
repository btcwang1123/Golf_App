import Foundation

public struct SGBreakdown: Sendable, Codable, Equatable, Hashable {
    public var offTee: Double = 0
    public var approach: Double = 0
    public var shortGame: Double = 0
    public var putting: Double = 0
    public var holesCounted = 0
    /// Holes skipped because map data is not `.full` or shots lack GPS.
    public var holesExcluded = 0

    public init() {}

    public var total: Double { offTee + approach + shortGame + putting }

    public static func + (a: SGBreakdown, b: SGBreakdown) -> SGBreakdown {
        var r = SGBreakdown()
        r.offTee = a.offTee + b.offTee
        r.approach = a.approach + b.approach
        r.shortGame = a.shortGame + b.shortGame
        r.putting = a.putting + b.putting
        r.holesCounted = a.holesCounted + b.holesCounted
        r.holesExcluded = a.holesExcluded + b.holesExcluded
        return r
    }
}

public enum StrokesGained {
    public enum Category: String, Sendable, CaseIterable {
        case offTee, approach, shortGame, putting
    }

    /// Distance to target at or below which a non-green shot is short game.
    public static let shortGameMeters = 30.0

    public static func category(shotIndex: Int, par: Int?, lie: Lie, distance: Double) -> Category {
        if shotIndex == 0, (par ?? 4) >= 4 { return .offTee }
        if lie == .green { return .putting }
        return distance > shortGameMeters ? .approach : .shortGame
    }

    public static func compute(state: RoundState, course: Course?) -> SGBreakdown {
        var out = SGBreakdown()
        guard let course else {
            out.holesExcluded = state.holes.filter { $0.total > 0 }.count
            return out
        }
        for h in state.holes where h.total > 0 {
            guard let hole = course.hole(h.number), HoleQuality.evaluate(hole).isComplete,
                  let sg = holeBreakdown(h, hole: hole, pin: state.pins[h.number]) else {
                out.holesExcluded += 1
                continue
            }
            out = out + sg
        }
        return out
    }

    static func holeBreakdown(_ h: HoleState, hole: Hole, pin: GeoPoint?) -> SGBreakdown? {
        guard let target = pin ?? hole.effectiveGreenCenter else { return nil }
        let shots = h.shots
        let firstPutt = shots.firstIndex { $0.type == .putt }
        // Every non-putt shot needs a fix.
        let fullShots = shots.prefix(firstPutt ?? shots.count)
        guard !fullShots.isEmpty || firstPutt != nil, fullShots.allSatisfy({ $0.location != nil }) else { return nil }
        let penalized = Set(h.penalizedShotIds)

        func state(_ i: Int) -> (expected: Double, lie: Lie, dist: Double)? {
            guard i < shots.count else { return (0, .green, 0) } // holed
            if shots[i].type == .putt {
                guard let loc = shots[i].location else { return nil }
                let d = Geo.distance(loc, target)
                return (BaselineTable.expected(distance: d, lie: .green), .green, d)
            }
            guard let loc = shots[i].location else { return nil }
            var lie = LieClassifier.classify(loc, hole: hole)
            if i == 0 { lie = .tee }
            let d = Geo.distance(loc, target)
            return (BaselineTable.expected(distance: d, lie: lie), lie, d)
        }

        var out = SGBreakdown()
        var i = 0
        while i < shots.count {
            let isPutt = shots[i].type == .putt
            if isPutt, shots[i].location == nil {
                // Putts without GPS: whole putting phase vs expectation.
                let putts = shots.count - i
                out.putting += BaselineTable.defaultPuttExpectation - Double(putts)
                break
            }
            guard let before = state(i) else { return nil }
            var after = state(i + 1)
            if after == nil, i + 1 < shots.count, shots[i + 1].type == .putt {
                after = (BaselineTable.defaultPuttExpectation, .green, 0)
            }
            guard let after else { return nil }
            var sg = before.expected - after.expected - 1
            if penalized.contains(shots[i].id) { sg -= 1 }
            switch category(shotIndex: i, par: h.par ?? hole.par, lie: before.lie, distance: before.dist) {
            case .offTee: out.offTee += sg
            case .approach: out.approach += sg
            case .shortGame: out.shortGame += sg
            case .putting: out.putting += sg
            }
            i += 1
        }
        out.holesCounted = 1
        return out
    }
}
