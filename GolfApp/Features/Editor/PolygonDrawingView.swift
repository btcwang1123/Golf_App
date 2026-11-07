import GolfKit
import MapKit
import SwiftUI

struct PolygonDrawingView: View {
    let model: EditorModel
    @State private var position: MapCameraPosition = .automatic
    @State private var dragStarted = false

    private static let cameraDistance: Double = 500
    private static let space = "editorMap"

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(Array(model.course.features.enumerated()), id: \.offset) { _, f in
                    MapPolygon(coordinates: f.polygon.map(\.coordinate))
                        .foregroundStyle(MapPalette.fill(for: f.kind).opacity(0.25))
                }
                if let hole = model.currentHole {
                    ForEach(Array(hole.features.enumerated()), id: \.offset) { i, f in
                        MapPolygon(coordinates: f.polygon.map(\.coordinate))
                            .foregroundStyle(MapPalette.fill(for: f.kind).opacity(model.selectedFeature == i ? 0.6 : 0.45))
                            .stroke(model.selectedFeature == i ? Theme.gold : MapPalette.fill(for: f.kind), lineWidth: model.selectedFeature == i ? 2.5 : 1.5)
                    }
                    if let tee = hole.tee {
                        Marker("T", coordinate: tee.coordinate).tint(MapPalette.tee)
                    }
                    if let g = hole.greenCenter {
                        Marker("G", coordinate: g.coordinate).tint(MapPalette.green)
                    }
                    vertexHandles(hole, proxy: proxy)
                }
                if model.draftPolygon.count >= 2 {
                    MapPolyline(coordinates: model.draftPolygon.map(\.coordinate))
                        .stroke(Theme.gold, lineWidth: 3)
                }
                ForEach(Array(model.draftPolygon.enumerated()), id: \.offset) { _, p in
                    Annotation("", coordinate: p.coordinate) {
                        Circle().fill(Theme.gold).frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 1))
                    }
                }
            }
            .mapStyle(.imagery)
            .coordinateSpace(.named(Self.space))
            .gesture(
                SpatialTapGesture().onEnded { value in
                    if let c = proxy.convert(value.location, from: .local) {
                        model.tap(at: GeoPoint(c))
                    }
                }
            )
        }
        .overlay(alignment: .topLeading) {
            if let p = model.dragging {
                MagnifierView(point: p).padding(12).transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.snappy, value: model.dragging != nil)
        .onAppear { recenter() }
        .onChange(of: model.currentHoleNumber) { _, _ in recenter() }
    }

    @MapContentBuilder
    private func vertexHandles(_ hole: Hole, proxy: MapProxy) -> some MapContent {
        if model.tool == .edit, let fi = model.selectedFeature, hole.features.indices.contains(fi) {
            let poly = hole.features[fi].polygon
            ForEach(Array(poly.enumerated()), id: \.offset) { vi, v in
                Annotation("", coordinate: v.coordinate) {
                    Circle().fill(Theme.ivory).frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Theme.gold, lineWidth: 2))
                        .contentShape(Circle().inset(by: -10))
                        .gesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
                                .onChanged { value in
                                    if !dragStarted { model.beginDrag(); dragStarted = true }
                                    if let c = proxy.convert(value.location, from: .named(Self.space)) {
                                        model.moveVertex(polygon: fi, index: vi, to: GeoPoint(c))
                                    }
                                }
                                .onEnded { value in
                                    if let c = proxy.convert(value.location, from: .named(Self.space)) {
                                        model.moveVertex(polygon: fi, index: vi, to: GeoPoint(c), final: true)
                                    }
                                    dragStarted = false
                                })
                        .onLongPressGesture { model.deleteVertex(polygon: fi, index: vi) }
                        .accessibilityLabel("頂點 \(vi + 1)")
                }
            }
            ForEach(Array(poly.enumerated()), id: \.offset) { vi, v in
                let next = poly[(vi + 1) % poly.count]
                let mid = Geo.midpoint(v, next)
                Annotation("", coordinate: mid.coordinate) {
                    Button { model.insertVertex(polygon: fi, after: vi, at: mid) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.onGold)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Theme.gold.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("在此插入頂點")
                }
            }
        }
    }

    private func recenter() {
        let center: GeoPoint
        if let hole = model.currentHole, let t = hole.effectiveTee, let g = hole.effectiveGreenCenter {
            center = Geo.midpoint(t, g)
        } else if let t = model.currentHole?.effectiveTee ?? model.currentHole?.effectiveGreenCenter {
            center = t
        } else {
            center = model.course.center
        }
        position = .camera(MapCamera(centerCoordinate: center.coordinate, distance: Self.cameraDistance, heading: 0, pitch: 0))
    }
}
