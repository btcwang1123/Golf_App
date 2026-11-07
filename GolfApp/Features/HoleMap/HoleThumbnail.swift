import GolfKit
import SwiftUI

/// Low-poly top-down drawing of a hole (tee at the bottom, green at the top). No MapKit, cheap to render.
struct HoleThumbnail: View {
    let hole: Hole
    var course: Course?
    var showBackground = true

    var body: some View {
        Canvas { ctx, size in
            guard let proj = HoleProjection(hole: hole, size: size) else { return }
            func path(_ poly: Polygon) -> Path {
                var p = Path()
                guard let first = poly.first else { return p }
                p.move(to: proj.project(first))
                poly.dropFirst().forEach { p.addLine(to: proj.project($0)) }
                p.closeSubpath()
                return p
            }
            let features = (hole.features + extraFeatures(proj: proj, size: size))
                .filter { $0.polygon.count >= 3 && $0.kind != .outOfBounds }
                .sorted { MapPalette.drawOrder(for: $0.kind) < MapPalette.drawOrder(for: $1.kind) }
            for f in features {
                ctx.fill(path(f.polygon), with: .color(MapPalette.gameFill(for: f.kind)))
            }
            if let g = hole.green, g.count >= 3, !features.contains(where: { $0.kind == .green }) {
                ctx.fill(path(g), with: .color(MapPalette.green))
            }
            // Centre line.
            let line = hole.path.count >= 2 ? hole.path : [hole.effectiveTee, hole.effectiveGreenCenter].compactMap { $0 }
            if line.count >= 2 {
                var p = Path()
                p.move(to: proj.project(line[0]))
                line.dropFirst().forEach { p.addLine(to: proj.project($0)) }
                ctx.stroke(p, with: .color(Theme.ivory.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            // Low-poly trees along the hole.
            for tree in LowPolyScenery.treeSpots(course: course, hole: hole, limit: 40) {
                let c = proj.project(tree.point)
                guard c.x > -6, c.y > -6, c.x < size.width + 6, c.y < size.height + 6 else { continue }
                let s = 4.5 * tree.scale
                let leaf = MapPalette.treeHex[tree.tint % MapPalette.treeHex.count]
                var left = Path(), right = Path()
                left.addLines([CGPoint(x: c.x, y: c.y - s * 2.2), CGPoint(x: c.x - s, y: c.y), CGPoint(x: c.x, y: c.y)])
                right.addLines([CGPoint(x: c.x, y: c.y - s * 2.2), CGPoint(x: c.x, y: c.y), CGPoint(x: c.x + s, y: c.y)])
                ctx.fill(left, with: .color(Shade.color(leaf, brightness: 1.2)))
                ctx.fill(right, with: .color(Shade.color(leaf, brightness: 0.8)))
            }
            if let t = hole.effectiveTee {
                let c = proj.project(t)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(MapPalette.tee))
            }
            if let g = hole.effectiveGreenCenter {
                let c = proj.project(g)
                var flag = Path()
                flag.move(to: c)
                flag.addLine(to: CGPoint(x: c.x, y: c.y - 14))
                ctx.stroke(flag, with: .color(Theme.ivory), lineWidth: 1.2)
                var cloth = Path()
                cloth.move(to: CGPoint(x: c.x, y: c.y - 14))
                cloth.addLine(to: CGPoint(x: c.x + 8, y: c.y - 11))
                cloth.addLine(to: CGPoint(x: c.x, y: c.y - 8))
                ctx.fill(cloth, with: .color(MapPalette.pin))
            }
        }
        .background(showBackground ? AnyShapeStyle(Theme.mapColor(MapColors.rough).opacity(0.55)) : AnyShapeStyle(.clear))
        .accessibilityLabel("第 \(hole.number) 洞球道圖")
    }

    /// Course-level features near the hole (OSM often maps bunkers/fairways at course level).
    private func extraFeatures(proj: HoleProjection, size: CGSize) -> [Feature] {
        guard let course else { return [] }
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -20, dy: -20)
        return course.features.filter { f in f.polygon.contains { bounds.contains(proj.project($0)) } }
    }
}
