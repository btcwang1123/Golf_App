import Foundation

public enum Simplify {
    /// Douglas-Peucker simplification; first and last points are always kept.
    public static func douglasPeucker(_ points: [GeoPoint], epsilonMeters: Double) -> [GeoPoint] {
        guard points.count > 2, let origin = points.first else { return points }
        let pts = points.map { Geo.project($0, origin: origin) }
        var keep = [Bool](repeating: false, count: pts.count)
        keep[0] = true
        keep[pts.count - 1] = true
        var stack = [(0, pts.count - 1)]
        while let (s, e) = stack.popLast() {
            guard e > s + 1 else { continue }
            var maxD = 0.0, idx = s
            for i in (s + 1)..<e {
                let d = perpendicular(pts[i], pts[s], pts[e])
                if d > maxD { maxD = d; idx = i }
            }
            if maxD > epsilonMeters {
                keep[idx] = true
                stack.append((s, idx))
                stack.append((idx, e))
            }
        }
        return zip(points, keep).filter { $0.1 }.map { $0.0 }
    }

    private static func perpendicular(
        _ p: (x: Double, y: Double), _ a: (x: Double, y: Double), _ b: (x: Double, y: Double)
    ) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 == 0 { return ((p.x - a.x) * (p.x - a.x) + (p.y - a.y) * (p.y - a.y)).squareRoot() }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = min(1, max(0, t))
        let ex = a.x + t * dx - p.x, ey = a.y + t * dy - p.y
        return (ex * ex + ey * ey).squareRoot()
    }
}
