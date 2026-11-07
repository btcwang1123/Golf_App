import Foundation

public struct HazardDistance: Sendable, Codable, Equatable, Hashable, Identifiable {
    public enum Side: String, Sendable, Codable, Equatable, Hashable {
        case left, center, right
    }

    public var id: Int
    public var kind: Feature.Kind
    /// Meters along the line of play to the near edge.
    public var front: Double
    /// Meters along the line of play to carry the far edge.
    public var carry: Double
    public var side: Side
    public var polygon: Polygon

    public init(id: Int, kind: Feature.Kind, front: Double, carry: Double, side: Side, polygon: Polygon) {
        self.id = id
        self.kind = kind
        self.front = front
        self.carry = carry
        self.side = side
        self.polygon = polygon
    }
}

public enum HazardDistances {
    /// Lateral offset (m) under which a hazard counts as "center".
    public static let centerBand = 8.0

    /// Bunkers and water ahead of `from` toward the target (pin, else green center),
    /// at most `maxLateralMeters` off the line, sorted by front distance.
    public static func compute(
        from: GeoPoint, hole: Hole, target: GeoPoint? = nil, extraFeatures: [Feature] = [],
        maxLateralMeters: Double = 40
    ) -> [HazardDistance] {
        guard let aim = target ?? hole.effectiveGreenCenter else { return [] }
        let a = Geo.project(aim, origin: from)
        let len = (a.x * a.x + a.y * a.y).squareRoot()
        guard len > 1 else { return [] }
        let ux = a.x / len, uy = a.y / len
        var out: [HazardDistance] = []
        let features = (hole.features + extraFeatures).filter { CourseQuality.hazardKinds.contains($0.kind) && $0.polygon.count >= 3 }
        var seen = Set<Polygon>()
        for f in features where seen.insert(f.polygon).inserted {
            // Along/lateral coordinates of each vertex.
            let pts = f.polygon.map { p -> (along: Double, lat: Double) in
                let q = Geo.project(p, origin: from)
                return (q.x * ux + q.y * uy, q.x * uy - q.y * ux) // lat > 0 = right of line
            }
            // Intersections of the line of play with the polygon edges.
            var ts: [Double] = []
            for i in 0..<pts.count {
                let p = pts[i], q = pts[(i + 1) % pts.count]
                if (p.lat > 0) != (q.lat > 0), abs(q.lat - p.lat) > 1e-9 {
                    ts.append(p.along + (q.along - p.along) * (0 - p.lat) / (q.lat - p.lat))
                }
            }
            let front: Double, carry: Double, lateral: Double
            if let near = ts.min(), let far = ts.max() {
                front = near; carry = far; lateral = 0
            } else {
                let minLat = pts.map { abs($0.lat) }.min() ?? .infinity
                guard minLat <= maxLateralMeters else { continue }
                front = pts.map(\.along).min() ?? 0
                carry = pts.map(\.along).max() ?? 0
                let meanLat = pts.reduce(0) { $0 + $1.lat } / Double(pts.count)
                lateral = meanLat
            }
            guard front >= 0, front < len + 30 else { continue }
            let side: HazardDistance.Side = abs(lateral) < centerBand ? .center : (lateral > 0 ? .right : .left)
            out.append(HazardDistance(id: out.count, kind: f.kind, front: front, carry: carry, side: side, polygon: f.polygon))
        }
        return out.sorted { $0.front < $1.front }.enumerated().map { i, h in
            var c = h; c.id = i; return c
        }
    }
}
