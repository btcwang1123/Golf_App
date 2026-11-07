import GolfKit
import MapKit
import SwiftUI

/// Picks and orders the features to draw for a hole.
struct FeatureOverlay {
    struct Item: Identifiable {
        let id: Int
        let kind: Feature.Kind
        let coordinates: [CLLocationCoordinate2D]
    }

    let items: [Item]

    init(course: Course, hole: Hole?) {
        guard let hole else { items = []; return }
        var features = hole.features
        var seen = Set(features)
        if let box = Self.boundingBox(of: hole) {
            for f in course.features where !seen.contains(f) && Self.intersects(f.polygon, box) {
                seen.insert(f)
                features.append(f)
            }
        }
        let sorted = features
            .filter { $0.polygon.count >= 3 }
            .enumerated()
            .sorted {
                let a = MapPalette.drawOrder(for: $0.element.kind), b = MapPalette.drawOrder(for: $1.element.kind)
                return a == b ? $0.offset < $1.offset : a < b
            }
        items = sorted.enumerated().map { index, pair in
            Item(id: index, kind: pair.element.kind, coordinates: pair.element.polygon.map(\.coordinate))
        }
    }

    private struct Box {
        var minLat: Double, maxLat: Double, minLon: Double, maxLon: Double
    }

    private static func boundingBox(of hole: Hole) -> Box? {
        var pts = hole.path
        if let t = hole.effectiveTee { pts.append(t) }
        if let g = hole.effectiveGreenCenter { pts.append(g) }
        guard let first = pts.first else { return nil }
        var box = Box(minLat: first.lat, maxLat: first.lat, minLon: first.lon, maxLon: first.lon)
        for p in pts {
            box.minLat = min(box.minLat, p.lat); box.maxLat = max(box.maxLat, p.lat)
            box.minLon = min(box.minLon, p.lon); box.maxLon = max(box.maxLon, p.lon)
        }
        let padLat = MapStyleConfig.featurePaddingMeters / MapStyleConfig.metersPerDegreeLat
        let padLon = padLat / max(cos(first.lat * .pi / 180), 0.1)
        box.minLat -= padLat; box.maxLat += padLat
        box.minLon -= padLon; box.maxLon += padLon
        return box
    }

    private static func intersects(_ polygon: Polygon, _ box: Box) -> Bool {
        polygon.contains {
            $0.lat >= box.minLat && $0.lat <= box.maxLat && $0.lon >= box.minLon && $0.lon <= box.maxLon
        }
    }
}

/// Map content drawing the features in order.
struct FeatureOverlayContent: MapContent {
    let overlay: FeatureOverlay
    /// Game look: opaque cartoon fills with a light rim; rough is left to the low-poly ground.
    var game = false

    var body: some MapContent {
        ForEach(overlay.items) { item in
            if item.kind == .outOfBounds {
                MapPolyline(coordinates: item.coordinates + [item.coordinates[0]])
                    .stroke(MapPalette.outOfBounds, style: StrokeStyle(
                        lineWidth: MapStyleConfig.outOfBoundsLineWidth, dash: game ? [6, 5] : []))
            } else if game {
                if item.kind != .rough {
                    MapPolygon(coordinates: item.coordinates)
                        .foregroundStyle(MapPalette.gameFill(for: item.kind))
                        .stroke(MapPalette.gameRim(for: item.kind), lineWidth: MapPalette.gameRimWidth(for: item.kind))
                }
            } else {
                MapPolygon(coordinates: item.coordinates)
                    .foregroundStyle(MapPalette.fill(for: item.kind).opacity(MapStyleConfig.fillOpacity))
                    .stroke(MapPalette.stroke(for: item.kind), lineWidth: MapStyleConfig.strokeWidth)
            }
        }
    }
}
