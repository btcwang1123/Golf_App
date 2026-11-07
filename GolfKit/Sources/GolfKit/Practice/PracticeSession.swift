import Foundation

/// A driving-range session recorded on the watch: swings only, no score.
public struct PracticeSession: Sendable, Codable, Equatable, Hashable, Identifiable {
    public struct Swing: Sendable, Codable, Equatable, Hashable, Identifiable {
        public var id: UUID
        public var timestamp: Date
        public var metrics: SwingMetrics
        public var club: Club?

        public init(id: UUID = UUID(), timestamp: Date, metrics: SwingMetrics, club: Club? = nil) {
            self.id = id
            self.timestamp = timestamp
            self.metrics = metrics
            self.club = club
        }
    }

    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    /// Club in hand when a swing has none.
    public var club: Club?
    public var swings: [Swing]

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil, club: Club? = nil, swings: [Swing] = []) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.club = club
        self.swings = swings
    }

    public var duration: TimeInterval { max(0, (endedAt ?? swings.last?.timestamp ?? startedAt).timeIntervalSince(startedAt)) }
    public var tempo: TempoStats { TempoStats.make(sessions: [self]) }

    /// Swings per club (nil key = unspecified).
    public var countsByClub: [Club?: Int] {
        var out: [Club?: Int] = [:]
        for s in swings { out[s.club ?? club, default: 0] += 1 }
        return out
    }

    public static let fileExtension = "golfpractice"
}
