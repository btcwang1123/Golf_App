import GolfKit
import MapKit
import SwiftUI

/// Game-style low-poly scenery around a hole: a faceted grass mesh, and procedurally placed trees.
/// Built once per hole (deterministic, so the same hole always looks the same).
struct LowPolyScenery {
    struct Facet: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    struct Tree: Identifiable {
        let id: Int
        let point: GeoPoint
        let style: LowPolyTree.Style
        let tint: Int
        let scale: CGFloat
        var coordinate: CLLocationCoordinate2D { point.coordinate }
    }

    let base: [CLLocationCoordinate2D]
    let facets: [Facet]
    let trees: [Tree]
    /// Nearby OSM buildings (drawn by `LowPolyBuildings`, which depends on the camera angle).
    let buildings: [Building]

    static let empty = LowPolyScenery(base: [], facets: [], trees: [], buildings: [])

    private init(base: [CLLocationCoordinate2D], facets: [Facet], trees: [Tree], buildings: [Building]) {
        self.base = base
        self.facets = facets
        self.trees = trees
        self.buildings = buildings
    }

    init(course: Course, hole: Hole?) {
        guard let hole, let frame = SceneFrame(hole: hole) else { self = .empty; return }
        var rng = SeededRandom(seed: frame.seed)
        base = Self.baseSquare(frame: frame)
        facets = Self.groundMesh(frame: frame, rng: &rng)
        buildings = LowPolyBuildings.nearby(
            BuildingStore.buildings(for: course), hole: hole, radius: Config.buildingRadius)
        trees = Self.trees(course: course, hole: hole, frame: frame, limit: Config.maxTrees,
                           extraBlockers: Self.buildingBlockers(buildings, hole: hole), rng: &rng)
    }

    /// Tree positions only (for the cheap Canvas thumbnail).
    static func treeSpots(course: Course?, hole: Hole, limit: Int) -> [Tree] {
        guard let frame = SceneFrame(hole: hole) else { return [] }
        var rng = SeededRandom(seed: frame.seed)
        let buildings = course.map {
            LowPolyBuildings.nearby(BuildingStore.buildings(for: $0), hole: hole, radius: Config.buildingRadius)
        } ?? []
        return trees(course: course, hole: hole, frame: frame, limit: limit,
                     extraBlockers: buildingBlockers(buildings, hole: hole), rng: &rng)
    }

    /// Trees stay off footprints and off where the block is drawn from the default hole camera.
    private static func buildingBlockers(_ buildings: [Building], hole: Hole) -> [Polygon] {
        guard !buildings.isEmpty, let t = hole.effectiveTee, let g = hole.effectiveGreenCenter else {
            return buildings.map(\.footprint)
        }
        return LowPolyBuildings.treeBlockers(for: buildings, heading: Geo.bearing(t, g), pitch: MapStyleConfig.pitch)
    }

    enum Config {
        static let meshPadding = 220.0
        static let cellSize = 48.0
        static let maxFacets = 420
        static let baseHalfSize = 4000.0
        static let maxTrees = 70
        static let treeAttempts = 1400
        static let treeMinFromLine = 30.0
        static let treeMaxFromLine = 150.0
        static let treeClearance = 7.0
        static let otherHoleClearance = 22.0
        static let buildingRadius = 420.0
        /// Ground shading.
        static let groundBase: UInt32 = 0x4C8F4E
        static let groundFar: UInt32 = 0x3A7442
    }

    // MARK: Ground

    private static func baseSquare(frame: SceneFrame) -> [CLLocationCoordinate2D] {
        let s = Config.baseHalfSize
        return [(-s, -s), (s, -s), (s, s), (-s, s)].map {
            Geo.unproject(x: frame.cx + $0.0, y: frame.cy + $0.1, origin: frame.origin).coordinate
        }
    }

    private static func groundMesh(frame: SceneFrame, rng: inout SeededRandom) -> [Facet] {
        let pad = Config.meshPadding
        let minX = frame.minX - pad, maxX = frame.maxX + pad
        let minY = frame.minY - pad, maxY = frame.maxY + pad
        var cell = Config.cellSize
        while ((maxX - minX) / cell) * ((maxY - minY) / cell) * 2 > Double(Config.maxFacets) { cell *= 1.15 }
        let cols = max(1, Int(((maxX - minX) / cell).rounded(.up)))
        let rows = max(1, Int(((maxY - minY) / cell).rounded(.up)))

        // Jittered vertex grid (outer ring stays straight so the mesh edge is clean).
        var verts = [[(x: Double, y: Double)]]()
        for r in 0...rows {
            var row = [(x: Double, y: Double)]()
            for c in 0...cols {
                var x = minX + Double(c) * cell, y = minY + Double(r) * cell
                if r > 0, r < rows, c > 0, c < cols {
                    x += rng.next(in: -0.32...0.32) * cell
                    y += rng.next(in: -0.32...0.32) * cell
                }
                row.append((x, y))
            }
            verts.append(row)
        }

        var facets = [Facet]()
        func add(_ tri: [(x: Double, y: Double)], light: Double) {
            let mx = (tri[0].x + tri[1].x + tri[2].x) / 3, my = (tri[0].y + tri[1].y + tri[2].y) / 3
            let d = frame.distanceToLine(x: mx, y: my)
            let far = min(1, max(0, (d - 60) / 260))
            let color = Shade.mix(Config.groundBase, Config.groundFar, far, brightness: light + rng.next(in: -0.05...0.05))
            facets.append(Facet(
                id: facets.count,
                coordinates: tri.map { Geo.unproject(x: $0.x, y: $0.y, origin: frame.origin).coordinate },
                color: color))
        }
        for r in 0..<rows {
            for c in 0..<cols {
                let a = verts[r][c], b = verts[r][c + 1], cc = verts[r + 1][c + 1], d = verts[r + 1][c]
                // Alternate the diagonal for a less grid-like look; light from the north-west.
                if (r + c).isMultiple(of: 2) {
                    add([a, b, cc], light: 0.96)
                    add([a, cc, d], light: 1.05)
                } else {
                    add([a, b, d], light: 1.03)
                    add([b, cc, d], light: 0.97)
                }
            }
        }
        return facets
    }

    // MARK: Trees

    private static func trees(course: Course?, hole: Hole, frame: SceneFrame, limit: Int, extraBlockers: [Polygon],
                              rng: inout SeededRandom) -> [Tree] {
        let pad = Config.treeMaxFromLine
        let box = (minX: frame.minX - pad, maxX: frame.maxX + pad, minY: frame.minY - pad, maxY: frame.maxY + pad)
        func local(_ p: GeoPoint) -> (x: Double, y: Double) { Geo.project(p, origin: frame.origin) }
        func inBox(_ q: (x: Double, y: Double)) -> Bool {
            q.x >= box.minX && q.x <= box.maxX && q.y >= box.minY && q.y <= box.maxY
        }

        // Everything playable (this hole, other holes, course-level) blocks trees.
        var polys = hole.features.map(\.polygon)
        if let g = hole.green { polys.append(g) }
        var otherLines = [[(x: Double, y: Double)]]()
        if let course {
            polys += course.features.filter { $0.kind != .rough && $0.kind != .outOfBounds }.map(\.polygon)
            for h in course.holes where h.number != hole.number {
                polys += h.features.filter { $0.kind != .rough && $0.kind != .outOfBounds }.map(\.polygon)
                if let g = h.green { polys.append(g) }
                let line = h.path.count >= 2 ? h.path : [h.effectiveTee, h.effectiveGreenCenter].compactMap { $0 }
                let pts = line.map(local)
                if pts.contains(where: inBox) { otherLines.append(pts) }
            }
        }
        polys += extraBlockers
        polys = polys.filter { $0.count >= 3 }
        let blockers = polys.map { $0.map(local) }.filter { $0.contains(where: inBox) }
        let blockerRanges = blockers.map(Bounds.init)

        func blocked(_ q: (x: Double, y: Double)) -> Bool {
            for (i, poly) in blockers.enumerated() {
                guard blockerRanges[i].contains(q, pad: Config.treeClearance) else { continue }
                if LocalGeometry.contains(q, poly) { return true }
                if LocalGeometry.distanceToRing(q, poly) < Config.treeClearance { return true }
            }
            for line in otherLines where LocalGeometry.distanceToPolyline(q, line) < Config.otherHoleClearance {
                return true
            }
            return false
        }

        var accepted = [(x: Double, y: Double)]()
        var out = [Tree]()
        func tooClose(_ q: (x: Double, y: Double)) -> Bool {
            accepted.contains { ($0.x - q.x) * ($0.x - q.x) + ($0.y - q.y) * ($0.y - q.y) < 49 }
        }
        func place(_ q: (x: Double, y: Double)) {
            accepted.append(q)
            let roll = rng.next(in: 0...1)
            out.append(Tree(
                id: out.count,
                point: Geo.unproject(x: q.x, y: q.y, origin: frame.origin),
                style: roll < 0.55 ? .pine : (roll < 0.9 ? .round : .bush),
                tint: Int(rng.next(in: 0...2.999)),
                scale: CGFloat(rng.next(in: 0.8...1.25))))
        }

        var attempts = 0
        while out.count < limit, attempts < Config.treeAttempts {
            attempts += 1
            let q = (x: rng.next(in: box.minX...box.maxX), y: rng.next(in: box.minY...box.maxY))
            let d = frame.distanceToLine(x: q.x, y: q.y)
            guard d > Config.treeMinFromLine, d < Config.treeMaxFromLine else { continue }
            // Denser near the hole (tree-lined corridor), thinner further out.
            let keep = 1 - (d - Config.treeMinFromLine) / (Config.treeMaxFromLine - Config.treeMinFromLine) * 0.75
            guard rng.next(in: 0...1) < keep, !tooClose(q), !blocked(q) else { continue }
            place(q)
            // Small clumps of 1–3 extra trees.
            let extra = Int(rng.next(in: 0...3.4))
            for _ in 0..<extra where out.count < limit {
                let a = rng.next(in: 0...(2 * .pi)), r = rng.next(in: 8...15)
                let n = (x: q.x + cos(a) * r, y: q.y + sin(a) * r)
                let dn = frame.distanceToLine(x: n.x, y: n.y)
                if dn > Config.treeMinFromLine, !tooClose(n), !blocked(n) { place(n) }
            }
        }
        // Back-to-front relative to the tee (far trees first) so nearer ones overlap them.
        let dir = frame.direction
        return out
            .sorted {
                let a = local($0.point), b = local($1.point)
                return a.x * dir.x + a.y * dir.y > b.x * dir.x + b.y * dir.y
            }
            .enumerated()
            .map { Tree(id: $0.offset, point: $0.element.point, style: $0.element.style,
                        tint: $0.element.tint, scale: $0.element.scale) }
    }
}

// MARK: - Helpers

/// Local metric frame around a hole.
private struct SceneFrame {
    let origin: GeoPoint
    let line: [(x: Double, y: Double)]
    let minX: Double, maxX: Double, minY: Double, maxY: Double
    let seed: UInt64

    init?(hole: Hole) {
        let geoLine = hole.path.count >= 2 ? hole.path : [hole.effectiveTee, hole.effectiveGreenCenter].compactMap { $0 }
        guard let first = geoLine.first else { return nil }
        origin = first
        var pts = geoLine.map { Geo.project($0, origin: first) }
        if pts.count == 1 { pts.append((pts[0].x, pts[0].y + 1)) }
        line = pts
        minX = pts.map(\.x).min()!; maxX = pts.map(\.x).max()!
        minY = pts.map(\.y).min()!; maxY = pts.map(\.y).max()!
        let latBits = UInt64(bitPattern: Int64((first.lat * 1e6).rounded()))
        let lonBits = UInt64(bitPattern: Int64((first.lon * 1e6).rounded()))
        seed = latBits &* 0x9E37_79B9_7F4A_7C15 ^ lonBits &* 0xC2B2_AE3D_27D4_EB4F ^ UInt64(hole.number)
    }

    var cx: Double { (minX + maxX) / 2 }
    var cy: Double { (minY + maxY) / 2 }

    /// Unit vector from tee to green.
    var direction: (x: Double, y: Double) {
        let a = line[0], b = line[line.count - 1]
        let dx = b.x - a.x, dy = b.y - a.y, len = max((dx * dx + dy * dy).squareRoot(), 1e-6)
        return (dx / len, dy / len)
    }

    func distanceToLine(x: Double, y: Double) -> Double {
        LocalGeometry.distanceToPolyline((x, y), line)
    }
}

private struct Bounds {
    let minX: Double, maxX: Double, minY: Double, maxY: Double
    init(_ pts: [(x: Double, y: Double)]) {
        minX = pts.map(\.x).min() ?? 0; maxX = pts.map(\.x).max() ?? 0
        minY = pts.map(\.y).min() ?? 0; maxY = pts.map(\.y).max() ?? 0
    }
    func contains(_ q: (x: Double, y: Double), pad: Double) -> Bool {
        q.x >= minX - pad && q.x <= maxX + pad && q.y >= minY - pad && q.y <= maxY + pad
    }
}

private enum LocalGeometry {
    typealias P = (x: Double, y: Double)

    static func contains(_ p: P, _ poly: [P]) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    static func segmentDistance(_ p: P, _ a: P, _ b: P) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        let t = len2 == 0 ? 0 : min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        let ex = a.x + t * dx - p.x, ey = a.y + t * dy - p.y
        return (ex * ex + ey * ey).squareRoot()
    }

    static func distanceToPolyline(_ p: P, _ line: [P]) -> Double {
        guard let first = line.first else { return .infinity }
        if line.count == 1 { return segmentDistance(p, first, first) }
        var best = Double.infinity
        for i in 0..<(line.count - 1) { best = min(best, segmentDistance(p, line[i], line[i + 1])) }
        return best
    }

    static func distanceToRing(_ p: P, _ ring: [P]) -> Double {
        guard let first = ring.first else { return .infinity }
        return distanceToPolyline(p, ring + [first])
    }
}

/// Small deterministic PRNG (SplitMix64).
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x1234_5678 : seed }

    mutating func nextUInt() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(nextUInt() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

/// Color math for flat shading.
enum Shade {
    static func components(_ hex: UInt32) -> (Double, Double, Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    /// `hex` scaled by `brightness` (1 = unchanged).
    static func color(_ hex: UInt32, brightness: Double = 1) -> Color {
        let (r, g, b) = components(hex)
        return Color(.sRGB, red: min(1, r * brightness), green: min(1, g * brightness), blue: min(1, b * brightness))
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double, brightness: Double = 1) -> Color {
        let ca = components(a), cb = components(b)
        func m(_ x: Double, _ y: Double) -> Double { min(1, (x + (y - x) * t) * brightness) }
        return Color(.sRGB, red: m(ca.0, cb.0), green: m(ca.1, cb.1), blue: m(ca.2, cb.2))
    }
}

// MARK: - Map content

/// Faceted ground under the course features (hides the basemap around the hole).
struct LowPolyGroundContent: MapContent {
    let scenery: LowPolyScenery

    var body: some MapContent {
        if !scenery.base.isEmpty {
            MapPolygon(coordinates: scenery.base)
                .foregroundStyle(Shade.color(LowPolyScenery.Config.groundFar, brightness: 0.92))
        }
        ForEach(scenery.facets) { facet in
            MapPolygon(coordinates: facet.coordinates)
                .foregroundStyle(facet.color)
                // Same-color hairline hides anti-aliasing seams between facets.
                .stroke(facet.color, lineWidth: 0.8)
        }
    }
}

/// Billboarded low-poly trees.
struct LowPolyTreesContent: MapContent {
    let scenery: LowPolyScenery

    var body: some MapContent {
        ForEach(scenery.trees) { tree in
            Annotation("", coordinate: tree.coordinate, anchor: .bottom) {
                LowPolyTree(style: tree.style, tint: tree.tint)
                    .frame(width: 24 * tree.scale, height: 34 * tree.scale)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Tree sprite

/// A flat-shaded low-poly tree: lit left facets, shaded right facets, little trunk and ground shadow.
struct LowPolyTree: View {
    enum Style { case pine, round, bush }
    var style: Style
    var tint = 0

    private static let trunkHex: UInt32 = 0x7A5134

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let leaf = MapPalette.treeHex[tint % MapPalette.treeHex.count]
            let light = Shade.color(leaf, brightness: 1.22)
            let dark = Shade.color(leaf, brightness: 0.78)
            let mid = Shade.color(leaf)

            // Ground shadow.
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.12, y: h * 0.88, width: w * 0.76, height: h * 0.12)),
                     with: .color(.black.opacity(0.22)))

            func tri(_ pts: [CGPoint], _ c: Color) {
                var p = Path()
                p.addLines(pts)
                p.closeSubpath()
                ctx.fill(p, with: .color(c))
            }

            switch style {
            case .pine:
                ctx.fill(Path(CGRect(x: w * 0.44, y: h * 0.74, width: w * 0.12, height: h * 0.2)),
                         with: .color(Shade.color(Self.trunkHex)))
                // Three stacked tiers, each split down the middle.
                let tiers: [(top: CGFloat, bottom: CGFloat, half: CGFloat)] = [
                    (0.38, 0.82, 0.5), (0.18, 0.6, 0.4), (0.0, 0.38, 0.3),
                ]
                for t in tiers {
                    let apex = CGPoint(x: w / 2, y: h * t.top)
                    let base = h * t.bottom
                    let left = CGPoint(x: w * (0.5 - t.half), y: base)
                    let right = CGPoint(x: w * (0.5 + t.half), y: base)
                    let midB = CGPoint(x: w / 2, y: base + h * 0.03)
                    tri([apex, left, midB], light)
                    tri([apex, midB, right], dark)
                }
            case .round:
                ctx.fill(Path(CGRect(x: w * 0.44, y: h * 0.62, width: w * 0.12, height: h * 0.32)),
                         with: .color(Shade.color(Self.trunkHex)))
                // Faceted icosahedron-ish crown.
                let c = CGPoint(x: w / 2, y: h * 0.38)
                let r = w * 0.46
                let ring = (0..<6).map { i -> CGPoint in
                    let a = CGFloat(i) * .pi / 3 - .pi / 2
                    return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r * 0.92)
                }
                let shades = [light, mid, dark, dark, mid, light]
                for i in 0..<6 { tri([c, ring[i], ring[(i + 1) % 6]], shades[i]) }
                tri([CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.2), ring[0], ring[5]], Shade.color(leaf, brightness: 1.35))
            case .bush:
                let c = CGPoint(x: w / 2, y: h * 0.72)
                let r = w * 0.36
                let ring = (0..<6).map { i -> CGPoint in
                    let a = CGFloat(i) * .pi / 3 - .pi / 2
                    return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r * 0.75)
                }
                let shades = [light, mid, dark, dark, mid, light]
                for i in 0..<6 { tri([c, ring[i], ring[(i + 1) % 6]], shades[i]) }
            }
        }
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: 12) {
        LowPolyTree(style: .pine).frame(width: 48, height: 68)
        LowPolyTree(style: .round, tint: 1).frame(width: 48, height: 68)
        LowPolyTree(style: .bush, tint: 2).frame(width: 48, height: 68)
    }
    .padding()
    .background(Shade.color(LowPolyScenery.Config.groundBase))
}
