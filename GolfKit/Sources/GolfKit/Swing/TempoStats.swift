import Foundation

/// Backswing : downswing ratio analysis. Tour average is about 3 : 1.
public struct TempoStats: Sendable, Equatable {
    public enum Rating: String, Sendable, Equatable {
        case quick, ideal, slow

        public var title: String {
            switch self {
            case .quick: "偏快"
            case .ideal: "理想"
            case .slow: "偏慢"
            }
        }
    }

    public static let ideal = 3.0
    public static let idealRange = 2.6...3.4
    /// Values outside this range are sensor noise.
    public static let plausible = 0.8...8.0

    public var count: Int
    public var average: Double?
    public var standardDeviation: Double?
    /// Share of swings inside `idealRange` (0–1).
    public var idealShare: Double?
    public var byClub: [Club: Double]

    public static func rating(_ tempo: Double) -> Rating {
        tempo < idealRange.lowerBound ? .quick : tempo > idealRange.upperBound ? .slow : .ideal
    }

    public static func make(_ swings: [(tempo: Double, club: Club?)]) -> TempoStats {
        let valid = swings.filter { plausible.contains($0.tempo) }
        guard !valid.isEmpty else { return TempoStats(count: 0, average: nil, standardDeviation: nil, idealShare: nil, byClub: [:]) }
        let values = valid.map(\.tempo)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        var groups: [Club: [Double]] = [:]
        for s in valid { if let c = s.club { groups[c, default: []].append(s.tempo) } }
        return TempoStats(
            count: values.count, average: mean, standardDeviation: variance.squareRoot(),
            idealShare: Double(values.filter { idealRange.contains($0) }.count) / Double(values.count),
            byClub: groups.mapValues { $0.reduce(0, +) / Double($0.count) })
    }

    public static func make(rounds: [RoundState]) -> TempoStats {
        make(rounds.flatMap { r in r.holes.flatMap { h in h.shots.compactMap { s in s.swing.map { ($0.tempo, s.club) } } } })
    }

    public static func make(sessions: [PracticeSession]) -> TempoStats {
        make(sessions.flatMap { s in s.swings.map { ($0.metrics.tempo, $0.club ?? s.club) } })
    }
}
