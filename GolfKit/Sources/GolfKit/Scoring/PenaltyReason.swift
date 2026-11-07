import Foundation

/// Why a penalty stroke was taken.
public enum PenaltyReason: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case outOfBounds, water, lostBall, unplayable, other

    public var title: String {
        switch self {
        case .outOfBounds: "OB"
        case .water: "水障礙"
        case .lostBall: "遺失球"
        case .unplayable: "無法擊球"
        case .other: "其他"
        }
    }

    public var symbol: String {
        switch self {
        case .outOfBounds: "xmark.octagon"
        case .water: "drop"
        case .lostBall: "questionmark.circle"
        case .unplayable: "tree"
        case .other: "exclamationmark.triangle"
        }
    }
}
