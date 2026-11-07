import Foundation

public enum Geo {
    public static let earthRadiusMeters = 6_371_008.8

    /// Haversine distance in meters.
    public static func distance(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let p1 = a.lat * .pi / 180, p2 = b.lat * .pi / 180
        let dp = p2 - p1
        let dl = (b.lon - a.lon) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// Initial bearing in degrees [0, 360), 0 = north.
    public static func bearing(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let p1 = a.lat * .pi / 180, p2 = b.lat * .pi / 180
        let dl = (b.lon - a.lon) * .pi / 180
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Great-circle midpoint.
    public static func midpoint(_ a: GeoPoint, _ b: GeoPoint) -> GeoPoint {
        let p1 = a.lat * .pi / 180, l1 = a.lon * .pi / 180
        let p2 = b.lat * .pi / 180
        let dl = (b.lon - a.lon) * .pi / 180
        let bx = cos(p2) * cos(dl)
        let by = cos(p2) * sin(dl)
        let p3 = atan2(sin(p1) + sin(p2), sqrt((cos(p1) + bx) * (cos(p1) + bx) + by * by))
        let l3 = l1 + atan2(by, cos(p1) + bx)
        return GeoPoint(lat: p3 * 180 / .pi, lon: l3 * 180 / .pi)
    }

    /// Local equirectangular projection to meters (x = east, y = north) around `origin`.
    public static func project(_ p: GeoPoint, origin: GeoPoint) -> (x: Double, y: Double) {
        let k = earthRadiusMeters * .pi / 180
        return ((p.lon - origin.lon) * k * cos(origin.lat * .pi / 180), (p.lat - origin.lat) * k)
    }

    /// Inverse of `project(_:origin:)`.
    public static func unproject(x: Double, y: Double, origin: GeoPoint) -> GeoPoint {
        let k = earthRadiusMeters * .pi / 180
        let c = cos(origin.lat * .pi / 180)
        return GeoPoint(lat: origin.lat + y / k, lon: origin.lon + (c == 0 ? 0 : x / (k * c)))
    }

    /// Point `meters` away from `from` along `bearing` (degrees).
    public static func destination(from: GeoPoint, bearing: Double, meters: Double) -> GeoPoint {
        let b = bearing * .pi / 180
        return unproject(x: sin(b) * meters, y: cos(b) * meters, origin: from)
    }

    /// Point at `meters` along a polyline (clamped to its end).
    public static func point(along line: [GeoPoint], meters: Double) -> GeoPoint? {
        guard var prev = line.first else { return nil }
        var left = max(0, meters)
        for p in line.dropFirst() {
            let d = distance(prev, p)
            if d >= left, d > 0 {
                return destination(from: prev, bearing: bearing(prev, p), meters: left)
            }
            left -= d
            prev = p
        }
        return line.last
    }
}
