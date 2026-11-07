import Foundation

/// Derives a hole's tee, length and par from a green position and the fairways around it,
/// so a hole can be laid out with a single tap on the green.
public enum HoleAutoLayout {
    /// A fairway counts as leading to the green when its edge is this close (m).
    public static let maxGreenGapMeters = 45.0
    /// Ignore fairway points farther than this from the green (merged multi-hole fairways).
    public static let maxHoleMeters = 560.0
    /// Shorter estimates are treated as "no fairway found" (likely a par 3 or a stray patch).
    public static let minHoleMeters = 90.0

    /// The fairway end farthest from the green, on the fairway nearest to it; nil when no fairway leads there.
    public static func estimateTee(green: GeoPoint, fairways: [Polygon]) -> GeoPoint? {
        let near = fairways
            .filter { $0.count >= 3 }
            .map { poly -> (Polygon, Double) in
                let gap = PolygonOps.contains(green, in: poly) ? 0 : PolygonOps.distance(from: green, toPolyline: poly + [poly[0]])
                return (poly, gap)
            }
            .filter { $0.1 <= maxGreenGapMeters }
            .min { $0.1 < $1.1 }?.0
        guard let near else { return nil }
        let far = densified(near)
            .map { ($0, Geo.distance($0, green)) }
            .filter { $0.1 <= maxHoleMeters }
            .max { $0.1 < $1.1 }
        guard let far, far.1 >= minHoleMeters else { return nil }
        return far.0
    }

    /// Outline points every `stepMeters` (vertices alone miss long straight edges).
    static func densified(_ poly: Polygon, stepMeters: Double = 10) -> [GeoPoint] {
        var out: [GeoPoint] = []
        for (a, b) in zip(poly, poly.dropFirst() + [poly[0]]) {
            let n = max(1, Int(Geo.distance(a, b) / stepMeters))
            for i in 0..<n {
                let t = Double(i) / Double(n)
                out.append(GeoPoint(lat: a.lat + (b.lat - a.lat) * t, lon: a.lon + (b.lon - a.lon) * t))
            }
        }
        return out
    }

    /// Par from hole length (men's guideline: par 3 ≤ 230 m, par 4 ≤ 440 m).
    public static func guessPar(lengthMeters: Double) -> Int {
        lengthMeters <= 230 ? 3 : lengthMeters <= 440 ? 4 : 5
    }
}
