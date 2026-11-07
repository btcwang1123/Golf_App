import Foundation

public struct InsightsSummary: Sendable, Codable, Equatable, Hashable {
    public struct RoundPoint: Sendable, Codable, Equatable, Hashable, Identifiable {
        public var id: UUID
        public var date: Date
        public var holes: Int
        public var strokes: Int
        public var toPar: Int?
        public var puttsPerHole: Double?
        public var firPercent: Double?
        public var girPercent: Double?
        public var isManual: Bool
    }

    /// Rounds with this many holes or fewer count as 9-hole rounds.
    public static let nineHoleMax = 9
    public static let minRoundsForInsights = 3

    public var roundCount: Int
    public var averageScore18: Double?
    public var averageScore9: Double?
    public var best18: Int?
    public var best9: Int?
    /// Average over par, normalised to 18 holes.
    public var averageToPar: Double?
    public var firPercent: Double?
    public var girPercent: Double?
    public var puttsPerHole: Double?
    public var penaltiesPerRound: Double?
    /// Average score per par type (3/4/5).
    public var parTypeAverage: [Int: Double]
    public var breakdown: ScoringBreakdown
    /// Oldest → newest.
    public var trend: [RoundPoint]

    public var hasEnoughData: Bool { roundCount >= Self.minRoundsForInsights }

    /// - Parameter lastN: newest N rounds, nil for all.
    public static func make(rounds: [RoundState], courses: [String: Course], lastN: Int?) -> InsightsSummary {
        let played = rounds
            .filter { $0.totalStrokes > 0 }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
        let picked = lastN.map { Array(played.prefix($0)) } ?? played

        var s18: [Int] = [], s9: [Int] = []
        var toParSum = 0, toParHoles = 0
        var firH = 0, firC = 0, girH = 0, girC = 0
        var putts = 0, puttHoles = 0, penalties = 0
        var parSums: [Int: (Int, Int)] = [:]
        var breakdown = ScoringBreakdown()
        var trend: [RoundPoint] = []

        for r in picked {
            let course = r.courseId.flatMap { courses[$0] }
            let stats = RoundStats(state: r, course: course)
            let manual = r.isManualEntry
            let holes = r.holesPlayed
            if holes <= nineHoleMax { s9.append(r.totalStrokes) } else { s18.append(r.totalStrokes) }
            var roundToPar = 0, roundParHoles = 0
            for h in r.holes where h.total > 0 {
                guard let par = h.par else { continue }
                roundToPar += h.total - par
                roundParHoles += 1
                breakdown.add(strokes: h.total, par: par)
                let cur = parSums[par] ?? (0, 0)
                parSums[par] = (cur.0 + h.total, cur.1 + 1)
            }
            toParSum += roundToPar; toParHoles += roundParHoles
            if !manual { firH += stats.firHits; firC += stats.firChances }
            girH += stats.girHits; girC += stats.girChances
            putts += stats.totalPutts; puttHoles += stats.holesPlayed
            penalties += stats.totalPenalties
            trend.append(RoundPoint(
                id: r.roundId, date: r.startedAt ?? .distantPast, holes: holes, strokes: r.totalStrokes,
                toPar: roundParHoles > 0 ? roundToPar : nil, puttsPerHole: stats.puttsPerHole,
                firPercent: manual ? nil : stats.firPercent, girPercent: stats.girPercent, isManual: manual))
        }

        func avg(_ v: [Int]) -> Double? { v.isEmpty ? nil : Double(v.reduce(0, +)) / Double(v.count) }
        return InsightsSummary(
            roundCount: picked.count,
            averageScore18: avg(s18), averageScore9: avg(s9),
            best18: s18.min(), best9: s9.min(),
            averageToPar: toParHoles > 0 ? Double(toParSum) / Double(toParHoles) * 18 : nil,
            firPercent: firC > 0 ? Double(firH) / Double(firC) * 100 : nil,
            girPercent: girC > 0 ? Double(girH) / Double(girC) * 100 : nil,
            puttsPerHole: puttHoles > 0 ? Double(putts) / Double(puttHoles) : nil,
            penaltiesPerRound: picked.isEmpty ? nil : Double(penalties) / Double(picked.count),
            parTypeAverage: parSums.filter { (3...5).contains($0.key) }.mapValues { Double($0.0) / Double($0.1) },
            breakdown: breakdown,
            trend: trend.reversed())
    }

    /// Trailing moving average with the given window.
    public static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1 else { return values }
        return values.indices.map { i in
            let slice = values[max(0, i - window + 1)...i]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }
}
