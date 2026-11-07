import Foundation

public struct GreenDistances: Sendable, Codable, Equatable, Hashable {
    public var front: GeoPoint
    public var center: GeoPoint
    public var back: GeoPoint

    public init(front: GeoPoint, center: GeoPoint, back: GeoPoint) {
        self.front = front
        self.center = center
        self.back = back
    }
}

extension Hole {
    /// Distance in meters used to estimate front/back when no green polygon is available.
    public static let estimatedGreenHalfDepthMeters = 12.0

    /// Front/center/back points of the green along the ray from `position` to the green center.
    /// With a green polygon: nearest/farthest ray intersections; otherwise center ±12 m.
    public func greenFrontCenterBack(from position: GeoPoint) -> GreenDistances? {
        guard let center = effectiveGreenCenter else { return nil }
        let c = Geo.project(center, origin: position)
        let len = (c.x * c.x + c.y * c.y).squareRoot()
        let d = len < 1e-6 ? (x: 0.0, y: 1.0) : (x: c.x / len, y: c.y / len)

        if let green, green.count >= 3 {
            let pts = green.map { Geo.project($0, origin: position) }
            var ts: [Double] = []
            for i in 0..<pts.count {
                let a = pts[i], b = pts[(i + 1) % pts.count]
                let ex = b.x - a.x, ey = b.y - a.y
                let denom = d.x * ey - d.y * ex
                if abs(denom) < 1e-12 { continue }
                let t = (a.x * ey - a.y * ex) / denom
                let s = (a.x * d.y - a.y * d.x) / denom
                if t >= 0, s >= 0, s <= 1 { ts.append(t) }
            }
            if let near = ts.min(), let far = ts.max(), far - near > 1e-6 {
                return GreenDistances(
                    front: Geo.unproject(x: d.x * near, y: d.y * near, origin: position),
                    center: center,
                    back: Geo.unproject(x: d.x * far, y: d.y * far, origin: position)
                )
            }
        }
        let h = Self.estimatedGreenHalfDepthMeters
        return GreenDistances(
            front: Geo.unproject(x: c.x - d.x * h, y: c.y - d.y * h, origin: position),
            center: center,
            back: Geo.unproject(x: c.x + d.x * h, y: c.y + d.y * h, origin: position)
        )
    }

    public func greenDistancesMeters(from position: GeoPoint) -> (front: Double, center: Double, back: Double)? {
        guard let g = greenFrontCenterBack(from: position) else { return nil }
        return (Geo.distance(position, g.front), Geo.distance(position, g.center), Geo.distance(position, g.back))
    }
}
