import Foundation

/// Turns Overpass `way["building"]` results into simplified `Building`s and assigns them to courses.
public enum OSMBuildingBuilder {
    public static let paddingMeters = 350.0
    public static let minAreaSquareMeters = 15.0
    public static let maxVertices = 10
    public static let metersPerLevel = 3.2

    public struct Box: Sendable, Equatable {
        public var south: Double, west: Double, north: Double, east: Double

        public func contains(_ p: GeoPoint) -> Bool {
            p.lat >= south && p.lat <= north && p.lon >= west && p.lon <= east
        }
    }

    /// Bounding box of all mapped points of a course, padded. Nil for courses without hole data.
    public static func box(for course: Course, padding: Double = paddingMeters) -> Box? {
        var pts = course.features.flatMap(\.polygon)
        for h in course.holes {
            pts += h.path + h.features.flatMap(\.polygon) + (h.green ?? [])
            if let t = h.tee { pts.append(t) }
            if let g = h.greenCenter { pts.append(g) }
        }
        guard course.holes.contains(where: { $0.effectiveTee != nil }), let first = pts.first else { return nil }
        var box = Box(south: first.lat, west: first.lon, north: first.lat, east: first.lon)
        for p in pts {
            box.south = min(box.south, p.lat); box.north = max(box.north, p.lat)
            box.west = min(box.west, p.lon); box.east = max(box.east, p.lon)
        }
        let dLat = padding / 111_320
        let dLon = dLat / max(cos(first.lat * .pi / 180), 0.1)
        box.south -= dLat; box.north += dLat
        box.west -= dLon; box.east += dLon
        return box
    }

    /// One Overpass query for buildings in all boxes.
    public static func overpassQuery(boxes: [Box]) -> String {
        let parts = boxes.map {
            String(format: "way[\"building\"](%.5f,%.5f,%.5f,%.5f);", $0.south, $0.west, $0.north, $0.east)
        }
        return "[out:json][timeout:240];(" + parts.joined() + ");out geom;"
    }

    public static func buildings(from response: OverpassResponse) -> [Building] {
        response.elements.compactMap { el in
            guard el.type == .way, let geom = el.geometry, geom.count >= 4 else { return nil }
            var ring = geom.map(\.point)
            if ring.first == ring.last { ring.removeLast() }
            guard ring.count >= 3 else { return nil }
            ring = simplify(ring)
            guard ring.count >= 3, area(ring) >= minAreaSquareMeters else { return nil }
            return Building(footprint: ring, height: height(tags: el.tags ?? [:]))
        }
    }

    /// Buildings whose centroid falls in the course box.
    public static func assign(_ buildings: [Building], to box: Box) -> [Building] {
        buildings.filter { b in PolygonOps.centroid(b.footprint).map(box.contains) ?? false }
    }

    // MARK: Helpers

    static func height(tags: [String: String]) -> Double {
        func number(_ s: String?) -> Double? {
            guard let s else { return nil }
            let digits = s.prefix { $0.isNumber || $0 == "." }
            return Double(digits)
        }
        if let h = number(tags["height"]), h > 1 { return min(h, 120) }
        if let l = number(tags["building:levels"]), l > 0 { return min(l * metersPerLevel + 1, 120) }
        switch tags["building"] ?? "" {
        case "house", "detached", "semidetached_house", "bungalow", "farm": return 7
        case "garage", "garages", "shed", "roof", "hut", "cabin", "kiosk", "carport": return 3.5
        case "apartments", "dormitory", "hotel": return 24
        case "commercial", "office", "retail", "public", "school", "hospital": return 15
        case "industrial", "warehouse", "factory", "greenhouse": return 9
        case "temple", "church", "shrine": return 10
        default: return 8
        }
    }

    /// Planar area in m².
    static func area(_ ring: Polygon) -> Double {
        guard let o = ring.first else { return 0 }
        let pts = ring.map { Geo.project($0, origin: o) }
        var a = 0.0
        for i in 0..<pts.count {
            let p = pts[i], q = pts[(i + 1) % pts.count]
            a += p.x * q.y - q.x * p.y
        }
        return abs(a) / 2
    }

    /// Douglas–Peucker on the ring, raising the tolerance until it has at most `maxVertices` points.
    static func simplify(_ ring: Polygon) -> Polygon {
        guard ring.count > 4, let o = ring.first else { return ring }
        let pts = ring.map { Geo.project($0, origin: o) }
        var tolerance = 0.6
        var keep = Array(0..<pts.count)
        repeat {
            keep = douglasPeucker(pts + [pts[0]], tolerance: tolerance).filter { $0 < pts.count }
            tolerance *= 1.6
        } while keep.count > maxVertices && tolerance < 50
        return keep.count >= 3 ? keep.map { ring[$0] } : ring
    }

    private static func douglasPeucker(_ pts: [(x: Double, y: Double)], tolerance: Double) -> [Int] {
        var keep = Set([0, pts.count - 1])
        var stack = [(0, pts.count - 1)]
        while let (s, e) = stack.popLast() {
            guard e > s + 1 else { continue }
            let a = pts[s], b = pts[e]
            let dx = b.x - a.x, dy = b.y - a.y, len = (dx * dx + dy * dy).squareRoot()
            var best = -1.0, idx = s
            for i in (s + 1)..<e {
                let p = pts[i]
                let d = len == 0
                    ? ((p.x - a.x) * (p.x - a.x) + (p.y - a.y) * (p.y - a.y)).squareRoot()
                    : abs(dy * p.x - dx * p.y + b.x * a.y - b.y * a.x) / len
                if d > best { best = d; idx = i }
            }
            if best > tolerance {
                keep.insert(idx)
                stack.append((s, idx)); stack.append((idx, e))
            }
        }
        return keep.sorted()
    }
}
