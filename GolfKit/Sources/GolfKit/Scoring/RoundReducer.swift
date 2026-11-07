import Foundation

public enum RoundReducer {
    /// Dedupe by id (first wins) and order by timestamp, then id.
    public static func merge(_ a: [RoundEvent], _ b: [RoundEvent]) -> [RoundEvent] {
        var seen = Set<UUID>()
        var out: [RoundEvent] = []
        for e in a + b where seen.insert(e.id).inserted { out.append(e) }
        return out.sorted(by: ordered)
    }

    private static func ordered(_ x: RoundEvent, _ y: RoundEvent) -> Bool {
        x.timestamp != y.timestamp ? x.timestamp < y.timestamp : x.id.uuidString < y.id.uuidString
    }

    public static func reduce(_ events: [RoundEvent], course: Course?) -> RoundState {
        let evs = merge(events, [])
        let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        var state = RoundState(roundId: evs.first?.roundId ?? zero)

        var voided = Set<UUID>()
        var clubs: [UUID: Club] = [:]
        var pars: [Int: Int] = [:]
        var penalties: [Int: Int] = [:]
        var penaltyTimes: [Int: [Date]] = [:]
        var reasons: [Int: [PenaltyReason]] = [:]
        var strokeEvents: [(id: UUID, hole: Int, type: RoundEvent.StrokeType, loc: GeoPoint?, swing: SwingMetrics?, ts: Date)] = []
        var lastGoTo: Int?
        var referenced: Set<Int> = []
        var owner = Player.owner()
        var friends: [Player] = []
        var removed = Set<UUID>()
        var scores: [UUID: [Int: PlayerScore]] = [:]

        for e in evs {
            switch e.kind {
            case .start(let cid):
                if state.startedAt == nil { state.startedAt = e.timestamp; state.courseId = cid }
            case .end:
                state.endedAt = e.timestamp
            case .stroke(let h, let t, let l, let s):
                strokeEvents.append((e.id, h, t, l, s, e.timestamp))
                referenced.insert(h)
            case .void(let id): voided.insert(id)
            case .penalty(let h, let n, let reason):
                penalties[h, default: 0] += n
                if let reason { reasons[h, default: []].append(contentsOf: Array(repeating: reason, count: max(n, 0))) }
                penaltyTimes[h, default: []].append(e.timestamp)
                referenced.insert(h)
            case .setPar(let h, let p):
                pars[h] = p
                referenced.insert(h)
            case .setClub(let id, let c): clubs[id] = c
            case .goToHole(let n):
                lastGoTo = n
                referenced.insert(n)
            case .addPlayer(let p):
                if p.isOwner {
                    owner = Player(id: owner.id, name: p.name, handicap: p.handicap, isOwner: true)
                } else if let i = friends.firstIndex(where: { $0.id == p.id }) {
                    friends[i] = p
                    removed.remove(p.id)
                } else if friends.count < Player.maxPerRound - 1 {
                    friends.append(p)
                    removed.remove(p.id)
                }
            case .removePlayer(let id):
                removed.insert(id)
            case .playerScore(let pid, let h, let n, let putts):
                guard pid != owner.id else { break }
                let score = PlayerScore(hole: h, strokes: n, putts: putts, timestamp: e.timestamp)
                // Events are time-ordered, so later scores replace earlier ones.
                scores[pid, default: [:]][h] = score
                referenced.insert(h)
            case .setPin(let h, let loc):
                state.pins[h] = loc
            case .setGame(let g):
                state.game = g
            case .setBets(let b):
                state.bets = b
            case .wolfPick(let h, let partner):
                state.wolfPicks[h] = WolfPick(partnerId: partner)
            case .unknown:
                break
            }
        }
        let activeFriends = friends.filter { !removed.contains($0.id) }
        state.players = [owner] + activeFriends
        state.playerScores = scores.filter { id, _ in activeFriends.contains { $0.id == id } }
        if state.courseId == nil { state.courseId = course?.id }

        let live = strokeEvents.filter { !voided.contains($0.id) }
        state.currentHole = lastGoTo ?? live.last?.hole ?? 1

        var numbers = Set(course?.holes.map(\.number) ?? [])
        if numbers.isEmpty { numbers.formUnion(1...max(18, referenced.max() ?? 18)) }
        numbers.formUnion(referenced)

        let pinsByHole = state.pins
        state.holes = numbers.sorted().map { n in
            let courseHole = course?.hole(n)
            let mine = live.filter { $0.hole == n }
            var shots: [ShotInfo] = []
            for (i, s) in mine.enumerated() {
                var dist: Double?
                if let loc = s.loc {
                    if let next = mine[(i + 1)...].first(where: { $0.loc != nil })?.loc {
                        dist = Geo.distance(loc, next)
                    } else if i == mine.count - 1, s.type != .putt,
                              let g = pinsByHole[n] ?? courseHole?.effectiveGreenCenter {
                        dist = Geo.distance(loc, g)
                    }
                }
                shots.append(ShotInfo(id: s.id, type: s.type, location: s.loc, club: clubs[s.id], swing: s.swing, distanceToNext: dist, timestamp: s.ts))
            }
            let pen = penalties[n] ?? 0
            let penalized = (penaltyTimes[n] ?? []).compactMap { t in shots.last(where: { $0.timestamp <= t })?.id }
            return HoleState(
                number: n, par: pars[n] ?? courseHole?.par, strokes: shots.count,
                putts: shots.filter { $0.type == .putt }.count, penalties: pen,
                total: shots.count + pen, shots: shots, penalizedShotIds: penalized,
                penaltyReasons: reasons[n] ?? [])
        }
        return state
    }
}

/// Merge two event lists: dedupe by id, sort by timestamp.
public func merge(_ a: [RoundEvent], _ b: [RoundEvent]) -> [RoundEvent] {
    RoundReducer.merge(a, b)
}
