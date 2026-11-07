import GolfKit
import MapKit
import SwiftUI

/// Bundled OSM building footprints near mapped courses (`buildings_tw.json`, built by `osm-buildings`).
enum BuildingStore {
    private static let index: [String: [Building]] = {
        guard let url = Bundle.main.url(forResource: "buildings_tw", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let index = try? BuildingIndex.decode(from: data) else { return [:] }
        return index
    }()

    static func buildings(for course: Course) -> [Building] {
        if let list = index[course.id] { return list }
        if let replaced = course.replaces, let list = index[replaced] { return list }
        return []
    }
}

/// Fake-3D low-poly blocks: each building is its footprint extruded toward the camera's look direction,
/// so it reads as a box from the current (oblique) camera. Rebuilt when the camera heading/pitch settles.
enum LowPolyBuildings {
    struct Facet: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        let fill: Color
        let edge: Color
    }

    static let maxBuildings = 160
    /// Shown buildings are scaled up a little so they stay readable from a hole-wide camera.
    static let heightScale = 1.0
    static let minHeight = 4.0

    private static let wallHex: [UInt32] = [0xF2E6D0, 0xEADBC6, 0xF5EFE6, 0xEBD3C4]
    private static let roofHex: [UInt32] = [0xD9725B, 0x5E8FB8, 0x9AA7B0, 0xE0A64F, 0x6FAE9E, 0xC9876B]

    /// Buildings within `radius` meters of the hole line, nearest first (capped).
    static func nearby(_ buildings: [Building], hole: Hole, radius: Double) -> [Building] {
        let line = hole.path.count >= 2 ? hole.path : [hole.effectiveTee, hole.effectiveGreenCenter].compactMap { $0 }
        guard !line.isEmpty else { return [] }
        return buildings
            .compactMap { b -> (Building, Double)? in
                guard let c = PolygonOps.centroid(b.footprint) else { return nil }
                let d = PolygonOps.distance(from: c, toPolyline: line)
                return d <= radius ? (b, d) : nil
            }
            .sorted { $0.1 < $1.1 }
            .prefix(maxBuildings)
            .map(\.0)
    }

    /// Ground offset (east, north meters) of a point `height` up, as seen from the camera.
    static func roofOffset(height: Double, heading: Double, pitch: Double) -> (x: Double, y: Double) {
        let t = tan(min(max(pitch, 0), 75) * .pi / 180)
        let h = heading * .pi / 180
        return (sin(h) * height * t, cos(h) * height * t)
    }

    static func facets(for buildings: [Building], heading: Double, pitch: Double) -> [Facet] {
        guard let origin = buildings.first?.footprint.first else { return [] }
        let h = heading * .pi / 180
        let forward = (x: sin(h), y: cos(h))
        // Light from the camera's front-left so left walls are lit, right walls shaded.
        let left = (x: -forward.y, y: forward.x)
        let lightLen = 2.0.squareRoot()
        let light = (x: (left.x - forward.x) / lightLen, y: (left.y - forward.y) / lightLen)

        struct Prepared { let ring: [(x: Double, y: Double)]; let depth: Double; let building: Building; let seed: Int }
        let prepared: [Prepared] = buildings.enumerated().map { i, b in
            var ring = b.footprint.map { Geo.project($0, origin: origin) }
            // Make the ring counter-clockwise so (dy, -dx) is the outward normal.
            var area = 0.0
            for k in 0..<ring.count {
                let p = ring[k], q = ring[(k + 1) % ring.count]
                area += p.x * q.y - q.x * p.y
            }
            if area < 0 { ring.reverse() }
            let cx = ring.map(\.x).reduce(0, +) / Double(ring.count)
            let cy = ring.map(\.y).reduce(0, +) / Double(ring.count)
            let latBits = Int((b.footprint[0].lat * 1e6).rounded()) &* 31 &+ Int((b.footprint[0].lon * 1e6).rounded())
            return Prepared(ring: ring, depth: cx * forward.x + cy * forward.y, building: b, seed: abs(latBits &+ i))
        }

        var out = [Facet]()
        func geo(_ p: (x: Double, y: Double)) -> CLLocationCoordinate2D {
            Geo.unproject(x: p.x, y: p.y, origin: origin).coordinate
        }
        // Far buildings first so nearer ones cover them.
        for p in prepared.sorted(by: { $0.depth > $1.depth }) {
            let height = max(p.building.height * heightScale, minHeight)
            let off = roofOffset(height: height, heading: heading, pitch: pitch)
            let wallHex = wallHex[p.seed % wallHex.count]
            let roofHex = roofHex[(p.seed / 7) % roofHex.count]
            let ring = p.ring
            let roof = ring.map { (x: $0.x + off.x, y: $0.y + off.y) }

            // Walls facing the camera (outward normal points back toward the viewer).
            var walls = [(quad: [(x: Double, y: Double)], depth: Double, shade: Double)]()
            for k in 0..<ring.count {
                let a = ring[k], b = ring[(k + 1) % ring.count]
                let dx = b.x - a.x, dy = b.y - a.y
                let len = (dx * dx + dy * dy).squareRoot()
                guard len > 0.3 else { continue }
                let n = (x: dy / len, y: -dx / len)
                guard n.x * forward.x + n.y * forward.y < 0 else { continue }
                let shade = 0.78 + 0.22 * (n.x * light.x + n.y * light.y)
                let mid = ((a.x + b.x) / 2) * forward.x + ((a.y + b.y) / 2) * forward.y
                walls.append(([a, b, roof[(k + 1) % ring.count], roof[k]], mid, shade))
            }
            for w in walls.sorted(by: { $0.depth > $1.depth }) {
                let c = Shade.color(wallHex, brightness: w.shade)
                out.append(Facet(id: out.count, coordinates: w.quad.map(geo), fill: c,
                                 edge: Shade.color(wallHex, brightness: w.shade * 0.82)))
            }
            out.append(Facet(id: out.count, coordinates: roof.map(geo), fill: Shade.color(roofHex),
                             edge: Shade.color(roofHex, brightness: 0.75)))
        }
        return out
    }

    /// Ground footprint plus roof area (where a tree would visually clash with the block).
    static func treeBlockers(for buildings: [Building], heading: Double, pitch: Double) -> [Polygon] {
        buildings.flatMap { b -> [Polygon] in
            guard let o = b.footprint.first else { return [] }
            let off = roofOffset(height: max(b.height, minHeight), heading: heading, pitch: pitch)
            let roof = b.footprint.map { p -> GeoPoint in
                let q = Geo.project(p, origin: o)
                return Geo.unproject(x: q.x + off.x, y: q.y + off.y, origin: o)
            }
            return [b.footprint, roof]
        }
    }
}

/// Map content for the building facets.
struct LowPolyBuildingsContent: MapContent {
    let facets: [LowPolyBuildings.Facet]

    var body: some MapContent {
        ForEach(facets) { f in
            MapPolygon(coordinates: f.coordinates)
                .foregroundStyle(f.fill)
                .stroke(f.edge, lineWidth: 0.8)
        }
    }
}
