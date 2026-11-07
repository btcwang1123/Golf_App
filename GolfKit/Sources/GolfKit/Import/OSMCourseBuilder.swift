import Foundation

/// Converts an Overpass `out geom` response into `Course` values.
public enum OSMCourseBuilder {
    public static let simplifyEpsilonMeters = 1.5
    public static let greenMatchMeters = 40.0
    public static let pinMatchMeters = 30.0
    public static let featureAssignMeters = 60.0
    public static let unnamedCourseName = "未命名球場"

    /// Single Overpass query for the whole of Taiwan (bbox south,west,north,east).
    public static let overpassQuery = """
    [out:json][timeout:180];
    (
      way["leisure"="golf_course"](21.8,119.3,25.4,122.1);
      relation["leisure"="golf_course"](21.8,119.3,25.4,122.1);
    )->.courses;
    .courses map_to_area -> .areas;
    (
      way["golf"~"^(hole|tee|fairway|green|bunker|water_hazard|lateral_water_hazard|rough)$"](area.areas);
      node["golf"="pin"](area.areas);
      way["natural"="water"](area.areas);
    )->.parts;
    (.courses; .parts;);
    out geom;
    """

    // MARK: - Public

    public static func build(from response: OverpassResponse) -> [Course] {
        let courseElements = response.elements
            .filter { $0.tag("leisure") == "golf_course" && $0.type != .node }
        var courses: [(id: String, outline: Polygon, course: Course)] = []
        for el in courseElements {
            guard let outline = ring(of: el), outline.count >= 3,
                  let center = PolygonOps.centroid(outline) else { continue }
            let id = "osm-\(el.type.rawValue)-\(el.id)"
            courses.append((id, outline, Course(
                id: id,
                name: el.tag("name:zh") ?? el.tag("name") ?? unnamedCourseName,
                county: el.tag("addr:city"),
                center: center,
                source: .osm
            )))
        }
        courses.sort { $0.id < $1.id }

        // Bucket parts by course.
        struct Bucket {
            var holes: [OverpassElement] = []
            var pins: [GeoPoint] = []
            var features: [(kind: Feature.Kind, polygon: Polygon)] = []
        }
        var buckets = [Bucket](repeating: Bucket(), count: courses.count)
        let parts = response.elements
            .filter { $0.tag("leisure") != "golf_course" }
            .sorted { ($0.type.rawValue, $0.id) < ($1.type.rawValue, $1.id) }

        for el in parts {
            let golf = el.tag("golf")
            let isHole = golf == "hole" && el.type == .way
            let isPin = golf == "pin"
            let kind = featureKind(el)
            guard isHole || isPin || kind != nil else { continue }
            let pts = points(of: el)
            guard let first = pts.first else { continue }
            let probe: GeoPoint
            if isHole || isPin || pts.count < 3 { probe = first }
            else { probe = PolygonOps.centroid(pts) ?? first }
            guard let ci = courses.firstIndex(where: { PolygonOps.contains(probe, in: $0.outline) }) else { continue }
            if isHole {
                buckets[ci].holes.append(el)
            } else if isPin {
                buckets[ci].pins.append(first)
            } else if let kind, let ringPts = ring(of: el), ringPts.count >= 3 {
                buckets[ci].features.append((kind, simplifyRing(ringPts)))
            }
        }

        return courses.enumerated().map { index, entry in
            var course = entry.course
            let bucket = buckets[index]
            let (holes, courseFeatures) = assemble(
                holeElements: bucket.holes, pins: bucket.pins, features: bucket.features)
            course.holes = holes
            course.features = courseFeatures
            return course
        }
    }

    // MARK: - Assembly

    private static func assemble(
        holeElements: [OverpassElement],
        pins: [GeoPoint],
        features: [(kind: Feature.Kind, polygon: Polygon)]
    ) -> ([Hole], [Feature]) {
        // Parse holes; ones without a ref get numbered after the max.
        var parsed: [(number: Int?, el: OverpassElement, path: [GeoPoint])] = []
        for el in holeElements {
            let path = points(of: el)
            guard path.count >= 2 else { continue }
            let number = el.tag("ref").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            parsed.append((number, el, path))
        }
        var next = (parsed.compactMap(\.number).max() ?? 0) + 1
        var holes: [Hole] = []
        var holePaths: [[GeoPoint]] = []
        var usedNumbers = Set<Int>()
        for item in parsed.sorted(by: { ($0.number ?? Int.max, $0.el.id) < ($1.number ?? Int.max, $1.el.id) }) {
            var number = item.number ?? 0
            if item.number == nil || usedNumbers.contains(number) {
                number = next
                next += 1
            }
            usedNumbers.insert(number)
            holes.append(Hole(
                number: number,
                par: item.el.tag("par").flatMap { Int($0) },
                handicap: item.el.tag("handicap").flatMap { Int($0) },
                tee: item.path.first,
                greenCenter: item.path.last,
                green: nil,
                path: Simplify.douglasPeucker(item.path, epsilonMeters: simplifyEpsilonMeters),
                features: []
            ))
            holePaths.append(item.path)
        }

        var consumed = Set<Int>() // indices of features already attached as green
        // Match greens.
        for hi in holes.indices {
            guard let end = holePaths[hi].last else { continue }
            var best: (idx: Int, dist: Double)?
            for (fi, f) in features.enumerated() where f.kind == .green && !consumed.contains(fi) {
                let d: Double
                if PolygonOps.contains(end, in: f.polygon) {
                    d = 0
                } else if let c = PolygonOps.centroid(f.polygon) {
                    d = Geo.distance(end, c)
                } else { continue }
                if d < greenMatchMeters, d < (best?.dist ?? .infinity) { best = (fi, d) }
            }
            if let best {
                consumed.insert(best.idx)
                let g = features[best.idx].polygon
                holes[hi].green = g
                holes[hi].greenCenter = PolygonOps.centroid(g) ?? end
                holes[hi].features.append(Feature(kind: .green, polygon: g))
            } else if let pin = pins
                .map({ ($0, Geo.distance(end, $0)) })
                .filter({ $0.1 < pinMatchMeters })
                .min(by: { $0.1 < $1.1 })?.0 {
                holes[hi].greenCenter = pin
            }
        }

        // Assign remaining features.
        var courseFeatures: [Feature] = []
        for (fi, f) in features.enumerated() where !consumed.contains(fi) {
            let feature = Feature(kind: f.kind, polygon: f.polygon)
            guard let c = PolygonOps.centroid(f.polygon) else { continue }
            var best: (idx: Int, dist: Double)?
            for hi in holes.indices {
                let d = PolygonOps.distance(from: c, toPolyline: holePaths[hi])
                if d < featureAssignMeters, d < (best?.dist ?? .infinity) { best = (hi, d) }
            }
            if let best { holes[best.idx].features.append(feature) }
            else { courseFeatures.append(feature) }
        }
        holes.sort { $0.number < $1.number }
        return (holes, courseFeatures)
    }

    // MARK: - Helpers

    static func featureKind(_ el: OverpassElement) -> Feature.Kind? {
        switch el.tag("golf") {
        case "fairway": return .fairway
        case "green": return .green
        case "tee": return .tee
        case "bunker": return .bunker
        case "water_hazard": return .water
        case "lateral_water_hazard": return .lateralWater
        case "rough": return .rough
        default: break
        }
        if el.tag("natural") == "water" { return .water }
        return nil
    }

    private static func simplifyRing(_ ring: Polygon) -> Polygon {
        let simplified = Simplify.douglasPeucker(ring, epsilonMeters: simplifyEpsilonMeters)
        return simplified.count >= 3 ? simplified : ring
    }

    /// Raw points of an element (node point, way geometry, or relation outer ring).
    private static func points(of el: OverpassElement) -> [GeoPoint] {
        switch el.type {
        case .node:
            if let lat = el.lat, let lon = el.lon { return [GeoPoint(lat: lat, lon: lon)] }
            return []
        case .way:
            return el.geometry?.map(\.point) ?? []
        case .relation:
            return ring(of: el) ?? []
        }
    }

    /// Polygon outline without a duplicated closing point.
    private static func ring(of el: OverpassElement) -> Polygon? {
        var pts: [GeoPoint]
        if el.type == .relation {
            let outers = (el.members ?? [])
                .filter { $0.type == "way" && ($0.role ?? "outer") == "outer" }
                .compactMap { $0.geometry?.map(\.point) }
                .filter { $0.count >= 2 }
            guard !outers.isEmpty else { return el.geometry.map { dropClosing($0.map(\.point)) } }
            pts = joinOuterRing(outers)
        } else {
            pts = el.geometry?.map(\.point) ?? []
        }
        pts = dropClosing(pts)
        return pts.isEmpty ? nil : pts
    }

    private static func dropClosing(_ pts: [GeoPoint]) -> [GeoPoint] {
        if pts.count > 1, pts.first == pts.last { return Array(pts.dropLast()) }
        return pts
    }

    /// Chains outer segments end-to-end starting from the first; stops at the first closed ring.
    private static func joinOuterRing(_ segments: [[GeoPoint]]) -> [GeoPoint] {
        var remaining = Array(segments.dropFirst())
        var ring = segments[0]
        while ring.first != ring.last, !remaining.isEmpty {
            guard let end = ring.last else { break }
            if let i = remaining.firstIndex(where: { $0.first == end || $0.last == end }) {
                var seg = remaining.remove(at: i)
                if seg.first != end { seg.reverse() }
                ring.append(contentsOf: seg.dropFirst())
            } else {
                break
            }
        }
        return ring
    }
}
