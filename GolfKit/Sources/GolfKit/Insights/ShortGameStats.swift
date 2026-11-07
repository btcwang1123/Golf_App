import Foundation

/// Scrambling, bunker play, putting and penalty breakdown over many rounds.
public struct ShortGameStats: Sendable, Equatable {
    public struct Rate: Sendable, Equatable {
        public var made: Int
        public var chances: Int
        public var percent: Double? { chances > 0 ? Double(made) / Double(chances) * 100 : nil }

        public init(made: Int = 0, chances: Int = 0) {
            self.made = made
            self.chances = chances
        }
    }

    public struct PuttBucket: Sendable, Equatable, Identifiable {
        public var label: String
        public var range: Range<Double>
        /// First putts from this distance.
        public var attempts: Int
        /// Of which holed (one putt).
        public var made: Int
        /// Of which three putts or worse.
        public var threePutts: Int
        public var id: String { label }
        public var makePercent: Double? { attempts > 0 ? Double(made) / Double(attempts) * 100 : nil }
    }

    /// Greenside bunker: within this many meters of the green center.
    public static let greensideMeters = 60.0
    public static let bucketEdges: [(String, Range<Double>)] = [
        ("< 1.5 m", 0..<1.5), ("1.5–3 m", 1.5..<3), ("3–6 m", 3..<6), ("6–10 m", 6..<10), ("10 m+", 10..<200),
    ]

    /// Missed the green in regulation but still made par or better.
    public var upAndDown: Rate
    /// Up and down in two from a greenside bunker.
    public var sandSave: Rate
    public var onePutts: Int
    public var threePutts: Int
    public var holesWithPutts: Int
    public var penaltiesByReason: [PenaltyReason: Int]
    public var unlabeledPenalties: Int
    public var averageFirstPuttMeters: Double?
    public var puttBuckets: [PuttBucket]

    public var totalPenalties: Int { penaltiesByReason.values.reduce(0, +) + unlabeledPenalties }

    public static func make(rounds: [RoundState], courses: [String: Course]) -> ShortGameStats {
        var ud = Rate(), ss = Rate()
        var one = 0, three = 0, withPutts = 0, unlabeled = 0
        var reasons: [PenaltyReason: Int] = [:]
        var firstPutt: [Double] = []
        var buckets = bucketEdges.map { PuttBucket(label: $0.0, range: $0.1, attempts: 0, made: 0, threePutts: 0) }

        for r in rounds {
            let course = r.courseId.flatMap { courses[$0] }
            for h in r.holes where h.total > 0 {
                for reason in h.penaltyReasons { reasons[reason, default: 0] += 1 }
                unlabeled += max(0, h.penalties - h.penaltyReasons.count)
                if h.putts > 0 {
                    withPutts += 1
                    if h.putts == 1 { one += 1 }
                    if h.putts >= 3 { three += 1 }
                }
                guard let par = h.par else { continue }
                if let before = h.strokesBeforeFirstPutt, before > par - 2 {
                    ud.chances += 1
                    if h.total <= par { ud.made += 1 }
                }
                let hole = course?.hole(h.number)
                if let hole, let green = r.pin(for: h.number) ?? hole.effectiveGreenCenter {
                    if let i = h.shots.lastIndex(where: { s in
                        guard s.type != .putt, let p = s.location else { return false }
                        return LieClassifier.classify(p, hole: hole) == .sand && Geo.distance(p, green) <= greensideMeters
                    }) {
                        ss.chances += 1
                        if h.shots.count - i - 1 <= 1, h.penalties == 0 { ss.made += 1 }
                    }
                }
                if let putt = h.shots.first(where: { $0.type == .putt }), let p = putt.location,
                   let target = r.pin(for: h.number) ?? hole?.effectiveGreenCenter {
                    let d = Geo.distance(p, target)
                    guard d < 60 else { continue }
                    firstPutt.append(d)
                    if let b = buckets.firstIndex(where: { $0.range.contains(d) }) {
                        buckets[b].attempts += 1
                        if h.putts == 1 { buckets[b].made += 1 }
                        if h.putts >= 3 { buckets[b].threePutts += 1 }
                    }
                }
            }
        }
        return ShortGameStats(
            upAndDown: ud, sandSave: ss, onePutts: one, threePutts: three, holesWithPutts: withPutts,
            penaltiesByReason: reasons, unlabeledPenalties: unlabeled,
            averageFirstPuttMeters: firstPutt.isEmpty ? nil : firstPutt.reduce(0, +) / Double(firstPutt.count),
            puttBuckets: buckets)
    }
}
