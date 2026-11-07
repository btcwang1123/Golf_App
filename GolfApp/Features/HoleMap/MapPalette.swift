import GolfKit
import SwiftUI

/// Low-poly colors per feature kind, from the shared `MapColors` constants via `Theme`.
enum MapPalette {
    static let fairway = Theme.mapColor(MapColors.fairway)
    static let green = Theme.mapColor(MapColors.green)
    static let tee = Theme.mapColor(MapColors.tee)
    static let rough = Theme.mapColor(MapColors.rough)
    static let bunker = Theme.mapColor(MapColors.bunker)
    static let water = Theme.mapColor(MapColors.water)
    static let outOfBounds = Theme.mapColor(MapColors.outOfBounds)
    static let shotLine = Theme.mapColor(MapColors.shotLine)
    static let shotMarker = Theme.mapColor(MapColors.shotMarker)
    static let player = Theme.mapColor(MapColors.player)
    static let pin = Theme.mapColor(MapColors.pin)
    static let target = Theme.mapColor(MapColors.target)
    static let markerText = Theme.ink
    static let markerRing = Theme.ivory

    static func fill(for kind: Feature.Kind) -> Color {
        Theme.mapColor(MapColors.fill(for: kind))
    }

    static func stroke(for kind: Feature.Kind) -> Color {
        fill(for: kind).opacity(MapStyleConfig.strokeOpacity)
    }

    // MARK: Game (low-poly scenery) style

    static let treeHex: [UInt32] = [0x2F8F4E, 0x3E9E45, 0x2A7D5A]

    /// Opaque, slightly brighter fills so features pop off the faceted ground.
    static func gameFill(for kind: Feature.Kind) -> Color {
        switch kind {
        case .fairway: Shade.color(0x6DBA5C)
        case .green: Shade.color(0x93DB7E)
        case .tee: Shade.color(0x8FD07A)
        case .bunker: Shade.color(0xEFDDA6)
        case .water, .lateralWater: Shade.color(0x4FA3DC)
        case .rough: Shade.color(MapColors.rough)
        case .outOfBounds: outOfBounds
        }
    }

    /// Light rim around each feature (fringe on greens, sand lip, shoreline).
    static func gameRim(for kind: Feature.Kind) -> Color {
        switch kind {
        case .fairway: Shade.color(0x8BCF6E)
        case .green: Shade.color(0xC2F0A6)
        case .tee: Shade.color(0xB5E59A)
        case .bunker: Shade.color(0xFFF6DA)
        case .water, .lateralWater: Shade.color(0xA8DDF5)
        case .rough, .outOfBounds: .clear
        }
    }

    static func gameRimWidth(for kind: Feature.Kind) -> CGFloat {
        switch kind {
        case .green, .water, .lateralWater: 3
        case .bunker, .fairway, .tee: 2
        case .rough, .outOfBounds: 0
        }
    }

    /// Lower draws first.
    static func drawOrder(for kind: Feature.Kind) -> Int {
        switch kind {
        case .rough: 0
        case .fairway: 1
        case .water, .lateralWater: 2
        case .bunker: 3
        case .tee: 4
        case .green: 5
        case .outOfBounds: 6
        }
    }
}

/// Tunable numbers for the hole map.
enum MapStyleConfig {
    static let pitch = 55.0
    static let distanceFactor = 2.2
    static let minDistance = 250.0
    static let singlePointDistance = 400.0
    static let noDataDistance = 1500.0
    /// Padding around the hole bounding box when picking course-level features.
    static let featurePaddingMeters = 120.0
    static let fillOpacity = 0.72
    static let strokeOpacity = 0.95
    static let strokeWidth = 1.0
    static let outOfBoundsLineWidth = 2.0
    static let shotLineWidth = 3.0
    static let targetLineWidth = 2.0
    static let arcLineWidth = 1.0
    static let arcSegments = 48
    /// Half-angle of the distance arcs around the line of play (degrees).
    static let arcHalfAngle = 35.0
    static let longPressDuration = 0.6
    static let metersPerDegreeLat = 111_320.0
    static let markerSize: CGFloat = 22
    static let pinSize: CGFloat = 26
    /// Taiwan `.realistic` terrain / overlay alignment must be verified on device (T39 manual check).
    static let useRealisticElevation = false
}
