import Foundation

public struct RoundStats: Sendable, Codable, Equatable, Hashable {
    public var firHits: Int
    public var firChances: Int
    public var girHits: Int
    public var girChances: Int
    public var totalPutts: Int
    public var totalPenalties: Int
    public var holesPlayed: Int

    public init(state: RoundState, course: Course?) {
        var fh = 0, fc = 0, gh = 0, gc = 0, putts = 0, pens = 0, played = 0
        for h in state.holes {
            putts += h.putts
            pens += h.penalties
            guard h.strokes > 0 else { continue }
            played += 1
            guard let par = h.par else { continue }

            gc += 1
            if let before = h.strokesBeforeFirstPutt, before <= par - 2 { gh += 1 }

            if par >= 4, h.shots.count >= 2, h.shots[0].type != .putt, let landing = h.shots[1].location {
                let courseHole = course?.hole(h.number)
                let fairways = ((courseHole?.features ?? []) + (course?.features ?? [])).filter { $0.kind == .fairway }
                if !fairways.isEmpty {
                    fc += 1
                    if fairways.contains(where: { PolygonOps.contains(landing, in: $0.polygon) }) { fh += 1 }
                }
            }
        }
        firHits = fh; firChances = fc; girHits = gh; girChances = gc
        totalPutts = putts; totalPenalties = pens; holesPlayed = played
    }

    public var firPercent: Double? { firChances > 0 ? Double(firHits) / Double(firChances) * 100 : nil }
    public var girPercent: Double? { girChances > 0 ? Double(girHits) / Double(girChances) * 100 : nil }
    public var puttsPerHole: Double? { holesPlayed > 0 ? Double(totalPutts) / Double(holesPlayed) : nil }

    /// Mean distanceToNext per club over all shots with a club (putter excluded).
    public static func averageDistanceByClub(_ states: [RoundState]) -> [Club: Double] {
        var sums: [Club: (Double, Int)] = [:]
        for s in states { for h in s.holes { for shot in h.shots {
            guard let c = shot.club, c != .putter, let d = shot.distanceToNext else { continue }
            let cur = sums[c] ?? (0, 0)
            sums[c] = (cur.0 + d, cur.1 + 1)
        } } }
        return sums.mapValues { $0.0 / Double($0.1) }
    }
}
