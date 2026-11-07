import Foundation

/// A whole-hole score of one player.
public struct PlayerScore: Sendable, Codable, Equatable, Hashable {
    public var hole: Int
    public var strokes: Int
    public var putts: Int?
    public var timestamp: Date

    public init(hole: Int, strokes: Int, putts: Int? = nil, timestamp: Date = Date()) {
        self.hole = hole
        self.strokes = strokes
        self.putts = putts
        self.timestamp = timestamp
    }
}
