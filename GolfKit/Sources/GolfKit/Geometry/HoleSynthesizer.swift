import Foundation

/// Builds holes for a course that has green polygons (OSM `golf=green`) but no `golf=hole` data:
/// each green becomes a hole with its center as the pin, tee / par estimated from the fairways
/// (`HoleAutoLayout`), and holes numbered along the shortest green → next tee walking route.
/// Numbering is a guess — the user can fix it in the course editor.
public enum HoleSynthesizer {
    /// Greens outside this area (m²) are ignored (tiny fragments, practice putting areas).
    public static let greenAreaRange = 120.0...2_000.0
    /// Two greens whose centers are closer than this are twin greens (A/B) of one hole.
    public static let twinGreenMeters = 50.0
    /// Fewer playable greens than this is not worth turning into holes.
    public static let minHoles = 2

    /// The course with holes added, or unchanged when it already has holes or too few greens.
    public static func apply(to course: Course) -> Course {
        guard course.holes.isEmpty, !course.name.contains("練習") else { return course }
        let holes = synthesize(features: course.features)
        guard holes.count >= minHoles else { return course }
        var c = course
        c.holes = holes
        return c
    }

    public static func apply(to list: [Course]) -> [Course] { list.map(apply(to:)) }

    static func synthesize(features: [Feature]) -> [Hole] {
        let greens = features
            .filter { $0.kind == .green && $0.polygon.count >= 3 && greenAreaRange.contains(area($0.polygon)) }
            .map(\.polygon)
        let fairways = features.filter { $0.kind == .fairway }.map(\.polygon)

        // One draft per hole: the larger of a twin-green pair is the target green.
        struct Draft { var green: Polygon; var center: GeoPoint; var tee: GeoPoint? }
        var drafts: [Draft] = []
        for poly in greens.sorted(by: { area($0) > area($1) }) {
            guard let center = PolygonOps.centroid(poly) else { continue }
            if drafts.contains(where: { Geo.distance($0.center, center) < twinGreenMeters }) { continue }
            drafts.append(Draft(green: poly, center: center,
                                tee: HoleAutoLayout.estimateTee(green: center, fairways: fairways)))
        }
        guard !drafts.isEmpty else { return [] }

        // Order: try each start, walk greedily to the hole whose tee is nearest the current green,
        // keep the route with the least walking between holes.
        let start = { (d: Draft) in d.tee ?? d.center }
        var best: [Int] = [], bestCost = Double.infinity
        for first in drafts.indices {
            var order = [first], left = Set(drafts.indices).subtracting([first]), cost = 0.0
            while let cur = order.last, !left.isEmpty {
                let next = left.min { Geo.distance(drafts[cur].center, start(drafts[$0])) < Geo.distance(drafts[cur].center, start(drafts[$1])) }!
                cost += Geo.distance(drafts[cur].center, start(drafts[next]))
                order.append(next)
                left.remove(next)
            }
            if cost < bestCost { bestCost = cost; best = order }
        }

        return best.enumerated().map { i, idx in
            let d = drafts[idx]
            return Hole(number: i + 1,
                        par: d.tee.map { HoleAutoLayout.guessPar(lengthMeters: Geo.distance($0, d.center)) },
                        tee: d.tee, greenCenter: d.center, green: d.green,
                        path: d.tee.map { [$0, d.center] } ?? [])
        }
    }

    /// Planar polygon area in m².
    static func area(_ polygon: Polygon) -> Double {
        guard let origin = polygon.first, polygon.count >= 3 else { return 0 }
        let pts = polygon.map { Geo.project($0, origin: origin) }
        var s = 0.0
        for (a, b) in zip(pts, pts.dropFirst() + [pts[0]]) { s += a.x * b.y - b.x * a.y }
        return abs(s) / 2
    }
}
