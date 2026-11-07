import Foundation

public struct ShotInfo: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var type: RoundEvent.StrokeType
    public var location: GeoPoint?
    public var club: Club?
    public var swing: SwingMetrics?
    /// Meters to the next located stroke, or to the green center for the last non-putt stroke.
    public var distanceToNext: Double?
    public var timestamp: Date

    public init(
        id: UUID, type: RoundEvent.StrokeType, location: GeoPoint? = nil, club: Club? = nil,
        swing: SwingMetrics? = nil, distanceToNext: Double? = nil, timestamp: Date
    ) {
        self.id = id
        self.type = type
        self.location = location
        self.club = club
        self.swing = swing
        self.distanceToNext = distanceToNext
        self.timestamp = timestamp
    }
}

public struct HoleState: Sendable, Codable, Equatable, Hashable {
    public var number: Int
    public var par: Int?
    /// Non-penalty strokes, putts included.
    public var strokes: Int
    public var putts: Int
    public var penalties: Int
    /// strokes + penalties
    public var total: Int
    public var shots: [ShotInfo]
    /// Shots followed by a penalty (the stroke that went into trouble).
    public var penalizedShotIds: [UUID]
    /// Reasons of penalties that were labelled (may be fewer than `penalties`).
    public var penaltyReasons: [PenaltyReason]

    public init(number: Int, par: Int? = nil, strokes: Int = 0, putts: Int = 0, penalties: Int = 0, total: Int = 0,
                shots: [ShotInfo] = [], penalizedShotIds: [UUID] = [], penaltyReasons: [PenaltyReason] = []) {
        self.penalizedShotIds = penalizedShotIds
        self.penaltyReasons = penaltyReasons
        self.number = number
        self.par = par
        self.strokes = strokes
        self.putts = putts
        self.penalties = penalties
        self.total = total
        self.shots = shots
    }

    /// Strokes (incl. penalties) taken before the first putt; nil if no putt was made.
    public var strokesBeforeFirstPutt: Int? {
        guard let i = shots.firstIndex(where: { $0.type == .putt }) else { return nil }
        return i + penalties
    }
}

public struct RoundState: Sendable, Codable, Equatable, Hashable {
    public var roundId: UUID
    public var courseId: String?
    public var startedAt: Date?
    public var endedAt: Date?
    public var currentHole: Int
    public var holes: [HoleState]
    /// Owner first, then friends in the order they were added.
    public var players: [Player]
    /// Whole-hole scores of non-owner players, keyed by player id then hole.
    public var playerScores: [UUID: [Int: PlayerScore]]
    /// Today's pin positions by hole.
    public var pins: [Int: GeoPoint]
    public var game: GameFormat
    /// Money games, nil when the group plays for nothing.
    public var bets: BetConfig?
    /// Wolf partner choices by hole.
    public var wolfPicks: [Int: WolfPick]

    public init(
        roundId: UUID, courseId: String? = nil, startedAt: Date? = nil, endedAt: Date? = nil,
        currentHole: Int = 1, holes: [HoleState] = [], players: [Player] = [.owner()],
        playerScores: [UUID: [Int: PlayerScore]] = [:], pins: [Int: GeoPoint] = [:], game: GameFormat = .stroke,
        bets: BetConfig? = nil, wolfPicks: [Int: WolfPick] = [:]
    ) {
        self.bets = bets
        self.wolfPicks = wolfPicks
        self.roundId = roundId
        self.courseId = courseId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.currentHole = currentHole
        self.holes = holes
        self.players = players
        self.playerScores = playerScores
        self.pins = pins
        self.game = game
    }

    /// Duration from the first to the last recorded event, or until `now` while playing.
    public func elapsed(now: Date = Date()) -> TimeInterval? {
        guard let startedAt else { return nil }
        return max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }

    public var owner: Player { players.first(where: \.isOwner) ?? .owner() }

    public func pin(for hole: Int) -> GeoPoint? { pins[hole] }

    /// Hole scores of a player. The owner's come from the stroke-by-stroke `holes`.
    public func scores(for playerId: UUID) -> [Int: PlayerScore] {
        if playerId == owner.id {
            var out: [Int: PlayerScore] = [:]
            for h in holes where h.total > 0 {
                out[h.number] = PlayerScore(
                    hole: h.number, strokes: h.total, putts: h.putts,
                    timestamp: h.shots.last?.timestamp ?? startedAt ?? Date(timeIntervalSince1970: 0))
            }
            return out
        }
        return playerScores[playerId] ?? [:]
    }

    public func total(for playerId: UUID) -> Int {
        scores(for: playerId).values.reduce(0) { $0 + $1.strokes }
    }

    /// Over scored holes with a known par; nil if none.
    public func toPar(for playerId: UUID) -> Int? {
        let s = scores(for: playerId)
        var diff = 0, any = false
        for (n, score) in s {
            guard let par = hole(n)?.par else { continue }
            diff += score.strokes - par
            any = true
        }
        return any ? diff : nil
    }

    /// Number of holes with a score for this player.
    public func holesPlayed(for playerId: UUID) -> Int { scores(for: playerId).count }

    public var isEnded: Bool { endedAt != nil }

    /// Hand-entered scorecard: no stroke carries GPS or swing data.
    public var isManualEntry: Bool {
        holes.allSatisfy { $0.shots.allSatisfy { $0.location == nil && $0.swing == nil } }
    }

    /// Holes with at least one stroke.
    public var holesPlayed: Int { holes.filter { $0.total > 0 }.count }

    public var totalStrokes: Int { holes.reduce(0) { $0 + $1.total } }

    /// Sum of (total - par) over holes that have a par and at least one stroke; nil if none.
    public var toPar: Int? {
        let scored = holes.filter { $0.par != nil && $0.strokes > 0 }
        guard !scored.isEmpty else { return nil }
        return scored.reduce(0) { $0 + $1.total - ($1.par ?? 0) }
    }

    public func hole(_ n: Int) -> HoleState? {
        holes.first { $0.number == n }
    }
}
