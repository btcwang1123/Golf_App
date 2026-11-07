import Foundation

/// A member of the playing group. The owner keeps a stroke-by-stroke record; friends enter whole-hole scores.
public struct Player: Sendable, Codable, Equatable, Hashable, Identifiable {
    public static let maxPerRound = 4

    public var id: UUID
    public var name: String
    public var handicap: Int?
    public var isOwner: Bool

    public init(id: UUID = UUID(), name: String, handicap: Int? = nil, isOwner: Bool = false) {
        self.id = id
        self.name = name
        self.handicap = handicap
        self.isOwner = isOwner
    }

    /// Stable id for the device owner in rounds without explicit players.
    public static let ownerId = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

    public static func owner(name: String = "我", handicap: Int? = nil) -> Player {
        Player(id: ownerId, name: name, handicap: handicap, isOwner: true)
    }
}
