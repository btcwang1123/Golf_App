import Foundation

/// Time spent per hole and whether the group keeps pace.
public struct PaceOfPlay: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        case ahead(minutes: Int)
        case onPace
        case behind(minutes: Int)
    }

    /// 4 h 15 min for 18 holes.
    public static let defaultMinutesPerHole = 14.0
    /// Within this many minutes counts as on pace.
    public static let tolerance = 5.0

    /// Seconds per played hole, from its first shot to the next hole's first shot (or its own last shot).
    public var holeSeconds: [Int: TimeInterval]
    public var elapsed: TimeInterval
    public var holesCompleted: Int

    public init(state: RoundState, now: Date = Date()) {
        let played = state.holes
            .filter { !$0.shots.isEmpty }
            .sorted { ($0.shots.first?.timestamp ?? .distantPast) < ($1.shots.first?.timestamp ?? .distantPast) }
        var secs: [Int: TimeInterval] = [:]
        for (i, h) in played.enumerated() {
            guard let start = h.shots.first?.timestamp else { continue }
            let end = i + 1 < played.count ? played[i + 1].shots.first?.timestamp : h.shots.last?.timestamp
            if let end { secs[h.number] = max(0, end.timeIntervalSince(start)) }
        }
        holeSeconds = secs
        elapsed = state.elapsed(now: now) ?? 0
        holesCompleted = state.holes.filter { $0.putts > 0 || ($0.total > 0 && $0.number != state.currentHole) }.count
    }

    public var averageMinutesPerHole: Double? {
        holesCompleted > 0 ? elapsed / 60 / Double(holesCompleted) : nil
    }

    public func projectedTotal(holeCount: Int) -> TimeInterval? {
        averageMinutesPerHole.map { $0 * 60 * Double(holeCount) }
    }

    public func status(minutesPerHole: Double = defaultMinutesPerHole) -> Status? {
        guard holesCompleted > 0 else { return nil }
        let diff = elapsed / 60 - Double(holesCompleted) * minutesPerHole
        if abs(diff) <= Self.tolerance { return .onPace }
        return diff > 0 ? .behind(minutes: Int(diff.rounded())) : .ahead(minutes: Int((-diff).rounded()))
    }

    /// Slowest played hole.
    public var slowestHole: (hole: Int, seconds: TimeInterval)? {
        holeSeconds.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }.map { ($0.key, $0.value) }
    }

    /// "4:12" style.
    public static func format(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        return String(format: "%d:%02d", m / 60, m % 60)
    }
}
