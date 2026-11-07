import GolfKit
import SwiftUI

/// Third page: the hole drawn with Canvas (no MapKit), tap a spot for distances, crown to zoom.
struct WatchHoleMapView: View {
    @Environment(WatchRoundStore.self) private var store
    @Environment(WatchLocationService.self) private var location
    @Environment(WatchSettingsService.self) private var settings
    @State private var zoom = 1.0
    @State private var tapped: GeoPoint?

    static let zoomRange = 1.0...3.0

    var body: some View {
        if let hole = store.currentHole, HoleQuality.evaluate(hole).isPlayable {
            GeometryReader { geo in
                let proj = HoleProjection(hole: hole, size: geo.size, zoom: zoom)
                ZStack {
                    Canvas { ctx, _ in
                        guard let proj else { return }
                        draw(hole: hole, proj: proj, ctx: &ctx)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { pt in tapped = proj?.unproject(pt) }
                    if let tapped, let proj {
                        labels(for: tapped, proj: proj)
                    }
                }
            }
            .focusable()
            .digitalCrownRotation($zoom, from: Self.zoomRange.lowerBound, through: Self.zoomRange.upperBound,
                                  by: 0.1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: store.currentHoleNumber) { tapped = nil; zoom = 1 }
            .accessibilityLabel("第 \(store.currentHoleNumber) 洞小地圖")
        } else {
            Text("此洞無圖資")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func draw(hole: Hole, proj: HoleProjection, ctx: inout GraphicsContext) {
        func path(_ poly: Polygon) -> Path {
            var p = Path()
            guard let f = poly.first else { return p }
            p.move(to: proj.project(f))
            poly.dropFirst().forEach { p.addLine(to: proj.project($0)) }
            p.closeSubpath()
            return p
        }
        let order: [Feature.Kind: Int] = [.rough: 0, .fairway: 1, .water: 2, .lateralWater: 2, .bunker: 3, .tee: 4, .green: 5]
        for f in hole.features.filter({ $0.kind != .outOfBounds && $0.polygon.count >= 3 }).sorted(by: { (order[$0.kind] ?? 0) < (order[$1.kind] ?? 0) }) {
            ctx.fill(path(f.polygon), with: .color(Color(mapHex: MapColors.fill(for: f.kind))))
        }
        if let g = hole.green, g.count >= 3 { ctx.fill(path(g), with: .color(Color(mapHex: MapColors.green))) }
        if let flag = store.flag {
            let c = proj.project(flag)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(Color(mapHex: MapColors.pin)))
        }
        if let me = location.current {
            let c = proj.project(me)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(Color(mapHex: MapColors.player)))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(.white), lineWidth: 1)
        }
        if let tapped {
            let c = proj.project(tapped)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)), with: .color(.white), lineWidth: 1.5)
        }
    }

    @ViewBuilder
    private func labels(for p: GeoPoint, proj: HoleProjection) -> some View {
        let s = settings.settings
        VStack(alignment: .leading, spacing: 0) {
            if let me = location.current {
                Text("我→點 \(s.format(meters: Geo.distance(me, p)))")
            }
            if let flag = store.flag {
                Text("點→旗 \(s.format(meters: Geo.distance(p, flag)))")
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .padding(4)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
