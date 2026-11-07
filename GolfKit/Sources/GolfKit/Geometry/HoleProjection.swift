import CoreGraphics
import Foundation

/// Projects a hole into a view rect with tee→green pointing up, uniformly scaled to fit.
public struct HoleProjection: Sendable {
    public let size: CGSize
    public let origin: GeoPoint
    /// Radians to rotate so that the hole bearing points up.
    public let rotation: Double
    public let scale: Double
    private let center: (x: Double, y: Double)

    public static let padding: CGFloat = 10

    public init?(hole: Hole, size: CGSize, zoom: Double = 1) {
        guard let tee = hole.effectiveTee, let green = hole.effectiveGreenCenter, size.width > 0, size.height > 0 else { return nil }
        var pts = hole.path + [tee, green] + (hole.green ?? [])
        for f in hole.features where f.kind != .outOfBounds { pts += f.polygon }
        self.init(points: pts, origin: tee, bearingDegrees: Geo.bearing(tee, green), size: size, zoom: zoom)
    }

    public init?(points: [GeoPoint], origin: GeoPoint, bearingDegrees: Double, size: CGSize, zoom: Double = 1) {
        guard !points.isEmpty else { return nil }
        self.size = size
        self.origin = origin
        self.rotation = bearingDegrees * .pi / 180
        let rotated = points.map { Self.rotate(Geo.project($0, origin: origin), by: bearingDegrees * .pi / 180) }
        let minX = rotated.map(\.x).min() ?? 0, maxX = rotated.map(\.x).max() ?? 0
        let minY = rotated.map(\.y).min() ?? 0, maxY = rotated.map(\.y).max() ?? 0
        let w = max(maxX - minX, 1), h = max(maxY - minY, 1)
        let availW = Double(size.width - 2 * Self.padding), availH = Double(size.height - 2 * Self.padding)
        self.scale = min(availW / w, availH / h) * max(zoom, 0.1)
        self.center = ((minX + maxX) / 2, (minY + maxY) / 2)
    }

    /// Rotate (east, north) meters so that `angle` (clockwise from north) points to +y.
    private static func rotate(_ p: (x: Double, y: Double), by angle: Double) -> (x: Double, y: Double) {
        (p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle))
    }

    public func project(_ p: GeoPoint) -> CGPoint {
        let r = Self.rotate(Geo.project(p, origin: origin), by: rotation)
        return CGPoint(
            x: Double(size.width) / 2 + (r.x - center.x) * scale,
            y: Double(size.height) / 2 - (r.y - center.y) * scale)
    }

    public func unproject(_ pt: CGPoint) -> GeoPoint {
        let rx = (Double(pt.x) - Double(size.width) / 2) / scale + center.x
        let ry = -(Double(pt.y) - Double(size.height) / 2) / scale + center.y
        // Inverse rotation.
        let x = rx * cos(rotation) + ry * sin(rotation)
        let y = -rx * sin(rotation) + ry * cos(rotation)
        return Geo.unproject(x: x, y: y, origin: origin)
    }
}
