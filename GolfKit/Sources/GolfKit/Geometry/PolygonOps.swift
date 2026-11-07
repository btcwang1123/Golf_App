import Foundation

public enum PolygonOps {
    /// Ray-casting point-in-polygon (works for concave polygons; closing point optional).
    public static func contains(_ p: GeoPoint, in polygon: Polygon) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let a = polygon[i], b = polygon[j]
            if (a.lat > p.lat) != (b.lat > p.lat),
               p.lon < (b.lon - a.lon) * (p.lat - a.lat) / (b.lat - a.lat) + a.lon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Area-weighted centroid; falls back to the vertex mean for degenerate polygons.
    public static func centroid(_ polygon: Polygon) -> GeoPoint? {
        guard let origin = polygon.first else { return nil }
        let pts = polygon.map { Geo.project($0, origin: origin) }
        var a2 = 0.0, cx = 0.0, cy = 0.0
        for i in 0..<pts.count {
            let p = pts[i], q = pts[(i + 1) % pts.count]
            let cross = p.x * q.y - q.x * p.y
            a2 += cross
            cx += (p.x + q.x) * cross
            cy += (p.y + q.y) * cross
        }
        if pts.count >= 3, abs(a2) > 1e-9 {
            return Geo.unproject(x: cx / (3 * a2), y: cy / (3 * a2), origin: origin)
        }
        let n = Double(pts.count)
        return Geo.unproject(x: pts.reduce(0) { $0 + $1.x } / n, y: pts.reduce(0) { $0 + $1.y } / n, origin: origin)
    }

    /// Shortest distance in meters from a point to a polyline. `.infinity` if empty.
    public static func distance(from p: GeoPoint, toPolyline line: [GeoPoint]) -> Double {
        guard let first = line.first else { return .infinity }
        if line.count == 1 { return Geo.distance(p, first) }
        let q = Geo.project(p, origin: p)
        let pts = line.map { Geo.project($0, origin: p) }
        var best = Double.infinity
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            let dx = b.x - a.x, dy = b.y - a.y
            let len2 = dx * dx + dy * dy
            var t = len2 == 0 ? 0 : ((q.x - a.x) * dx + (q.y - a.y) * dy) / len2
            t = min(1, max(0, t))
            let ex = a.x + t * dx - q.x, ey = a.y + t * dy - q.y
            best = min(best, (ex * ex + ey * ey).squareRoot())
        }
        return best
    }

    /// Nearest point on the polygon boundary.
    public static func nearestOnBoundary(_ p: GeoPoint, polygon: Polygon) -> GeoPoint? {
        guard polygon.count >= 2 else { return polygon.first }
        let pts = polygon.map { Geo.project($0, origin: p) }
        var best: (d: Double, x: Double, y: Double)?
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let dx = b.x - a.x, dy = b.y - a.y
            let len2 = dx * dx + dy * dy
            var t = len2 == 0 ? 0 : (-a.x * dx - a.y * dy) / len2
            t = min(1, max(0, t))
            let x = a.x + t * dx, y = a.y + t * dy
            let d = x * x + y * y
            if best == nil || d < best!.d { best = (d, x, y) }
        }
        guard let best else { return nil }
        return Geo.unproject(x: best.x, y: best.y, origin: p)
    }

    /// `p` if inside the polygon, else the nearest boundary point (snapped back onto the green).
    public static func clamp(_ p: GeoPoint, into polygon: Polygon) -> GeoPoint {
        guard polygon.count >= 3, !contains(p, in: polygon) else { return p }
        return nearestOnBoundary(p, polygon: polygon) ?? p
    }
}
