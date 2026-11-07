import Foundation

/// Round summary the watch app shares with its complication via an App Group.
public struct ComplicationSnapshot: Sendable, Codable, Equatable, Hashable {
    public static let appGroup = "group.com.bobby.golfapp"
    public static let defaultsKey = "complicationSnapshot.v1"
    /// Older snapshots are treated as "no round".
    public static let staleAfter: TimeInterval = 6 * 3600

    public var hole: Int
    public var strokes: Int
    public var distanceToPin: Double?
    public var updatedAt: Date

    public init(hole: Int, strokes: Int, distanceToPin: Double?, updatedAt: Date = Date()) {
        self.hole = hole
        self.strokes = strokes
        self.distanceToPin = distanceToPin
        self.updatedAt = updatedAt
    }

    public func isStale(now: Date = Date()) -> Bool { now.timeIntervalSince(updatedAt) > Self.staleAfter }
}
