import Foundation

/// A mapped area on a course or hole.
public struct Feature: Sendable, Codable, Equatable, Hashable {
    public enum Kind: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
        case fairway, green, tee, bunker, water, lateralWater, rough, outOfBounds
    }

    public var kind: Kind
    public var polygon: Polygon

    public init(kind: Kind, polygon: Polygon) {
        self.kind = kind
        self.polygon = polygon
    }
}
