import Foundation

public struct RoundEvent: Sendable, Codable, Equatable, Hashable, Identifiable {
    public enum Source: String, Sendable, Codable, Equatable, Hashable {
        case watch, phone
    }

    public enum StrokeType: String, Sendable, Codable, Equatable, Hashable {
        case swing, putt, manual
    }

    public enum Kind: Sendable, Equatable, Hashable {
        case start(courseId: String)
        case stroke(hole: Int, type: StrokeType, location: GeoPoint?, swing: SwingMetrics?)
        case void(strokeId: UUID)
        case penalty(hole: Int, count: Int, reason: PenaltyReason? = nil)
        case setPar(hole: Int, par: Int)
        case setClub(strokeId: UUID, club: Club)
        case goToHole(Int)
        case end
        // V2
        case addPlayer(Player)
        case removePlayer(UUID)
        case playerScore(playerId: UUID, hole: Int, strokes: Int, putts: Int?)
        case setPin(hole: Int, location: GeoPoint)
        case setGame(GameFormat)
        // V3
        /// Money games for the group; replaces earlier configs.
        case setBets(BetConfig)
        /// Wolf partner chosen on a hole; nil partner = lone wolf.
        case wolfPick(hole: Int, partnerId: UUID?)
        /// A kind written by a newer app version; ignored by the reducer.
        case unknown(String)
    }

    public var id: UUID
    public var roundId: UUID
    public var timestamp: Date
    public var source: Source
    public var kind: Kind

    public init(id: UUID = UUID(), roundId: UUID, timestamp: Date = Date(), source: Source, kind: Kind) {
        self.id = id
        self.roundId = roundId
        self.timestamp = timestamp
        self.source = source
        self.kind = kind
    }

    public static func make(roundId: UUID, source: Source, kind: Kind) -> RoundEvent {
        RoundEvent(id: UUID(), roundId: roundId, timestamp: Date(), source: source, kind: kind)
    }
}

extension RoundEvent.Kind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, courseId, hole, strokeType, location, swing, strokeId, count, par, club
        case player, playerId, strokes, putts, game
        case reason, bets, partnerId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "start":
            self = .start(courseId: try c.decode(String.self, forKey: .courseId))
        case "stroke":
            self = .stroke(
                hole: try c.decode(Int.self, forKey: .hole),
                type: try c.decode(RoundEvent.StrokeType.self, forKey: .strokeType),
                location: try c.decodeIfPresent(GeoPoint.self, forKey: .location),
                swing: try c.decodeIfPresent(SwingMetrics.self, forKey: .swing))
        case "void":
            self = .void(strokeId: try c.decode(UUID.self, forKey: .strokeId))
        case "penalty":
            self = .penalty(
                hole: try c.decode(Int.self, forKey: .hole), count: try c.decode(Int.self, forKey: .count),
                reason: try? c.decodeIfPresent(PenaltyReason.self, forKey: .reason))
        case "setPar":
            self = .setPar(hole: try c.decode(Int.self, forKey: .hole), par: try c.decode(Int.self, forKey: .par))
        case "setClub":
            self = .setClub(strokeId: try c.decode(UUID.self, forKey: .strokeId), club: try c.decode(Club.self, forKey: .club))
        case "goToHole":
            self = .goToHole(try c.decode(Int.self, forKey: .hole))
        case "end":
            self = .end
        case "addPlayer":
            self = .addPlayer(try c.decode(Player.self, forKey: .player))
        case "removePlayer":
            self = .removePlayer(try c.decode(UUID.self, forKey: .playerId))
        case "playerScore":
            self = .playerScore(
                playerId: try c.decode(UUID.self, forKey: .playerId),
                hole: try c.decode(Int.self, forKey: .hole),
                strokes: try c.decode(Int.self, forKey: .strokes),
                putts: try c.decodeIfPresent(Int.self, forKey: .putts))
        case "setPin":
            self = .setPin(hole: try c.decode(Int.self, forKey: .hole), location: try c.decode(GeoPoint.self, forKey: .location))
        case "setGame":
            self = .setGame(try c.decode(GameFormat.self, forKey: .game))
        case "setBets":
            self = .setBets(try c.decode(BetConfig.self, forKey: .bets))
        case "wolfPick":
            self = .wolfPick(hole: try c.decode(Int.self, forKey: .hole), partnerId: try c.decodeIfPresent(UUID.self, forKey: .partnerId))
        default:
            self = .unknown(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .start(let courseId):
            try c.encode("start", forKey: .type)
            try c.encode(courseId, forKey: .courseId)
        case .stroke(let hole, let type, let location, let swing):
            try c.encode("stroke", forKey: .type)
            try c.encode(hole, forKey: .hole)
            try c.encode(type, forKey: .strokeType)
            try c.encodeIfPresent(location, forKey: .location)
            try c.encodeIfPresent(swing, forKey: .swing)
        case .void(let strokeId):
            try c.encode("void", forKey: .type)
            try c.encode(strokeId, forKey: .strokeId)
        case .penalty(let hole, let count, let reason):
            try c.encode("penalty", forKey: .type)
            try c.encode(hole, forKey: .hole)
            try c.encode(count, forKey: .count)
            try c.encodeIfPresent(reason, forKey: .reason)
        case .setPar(let hole, let par):
            try c.encode("setPar", forKey: .type)
            try c.encode(hole, forKey: .hole)
            try c.encode(par, forKey: .par)
        case .setClub(let strokeId, let club):
            try c.encode("setClub", forKey: .type)
            try c.encode(strokeId, forKey: .strokeId)
            try c.encode(club, forKey: .club)
        case .goToHole(let n):
            try c.encode("goToHole", forKey: .type)
            try c.encode(n, forKey: .hole)
        case .end:
            try c.encode("end", forKey: .type)
        case .addPlayer(let p):
            try c.encode("addPlayer", forKey: .type)
            try c.encode(p, forKey: .player)
        case .removePlayer(let id):
            try c.encode("removePlayer", forKey: .type)
            try c.encode(id, forKey: .playerId)
        case .playerScore(let id, let hole, let strokes, let putts):
            try c.encode("playerScore", forKey: .type)
            try c.encode(id, forKey: .playerId)
            try c.encode(hole, forKey: .hole)
            try c.encode(strokes, forKey: .strokes)
            try c.encodeIfPresent(putts, forKey: .putts)
        case .setPin(let hole, let loc):
            try c.encode("setPin", forKey: .type)
            try c.encode(hole, forKey: .hole)
            try c.encode(loc, forKey: .location)
        case .setGame(let g):
            try c.encode("setGame", forKey: .type)
            try c.encode(g, forKey: .game)
        case .setBets(let b):
            try c.encode("setBets", forKey: .type)
            try c.encode(b, forKey: .bets)
        case .wolfPick(let hole, let partner):
            try c.encode("wolfPick", forKey: .type)
            try c.encode(hole, forKey: .hole)
            try c.encodeIfPresent(partner, forKey: .partnerId)
        case .unknown(let type):
            try c.encode(type, forKey: .type)
        }
    }
}
