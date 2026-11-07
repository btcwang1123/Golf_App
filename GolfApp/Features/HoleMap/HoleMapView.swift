import GolfKit
import MapKit
import SwiftUI

struct HoleMapView: View {
    let course: Course
    let hole: Hole?
    let shots: [ShotInfo]
    let player: GeoPoint?
    @Binding var target: GeoPoint?
    var pin: GeoPoint?
    var hazards: [HazardDistance] = []
    /// Increment to play the hole flyover.
    var flyoverTrigger = 0
    /// Default aim point when no target has been placed.
    var defaultTarget: GeoPoint?
    var onLongPress: ((GeoPoint) -> Void)?
    /// Pin edit mode: the pin is draggable and snaps into the green.
    var editingPin = false
    var onPinMove: ((GeoPoint) -> Void)?
    /// Animate the camera when the hole changes; off when the caller covers the switch with a fade.
    var animatesHoleChange = true

    @Environment(SettingsService.self) private var settingsService
    @State private var position: MapCameraPosition
    @State private var useSatellite = false
    @State private var selectedHazard: HazardDistance?
    @State private var showIntro = false
    @State private var mapIdentity = 0
    @State private var dragPin: GeoPoint?
    @State private var scenery: LowPolyScenery
    @State private var overlay: FeatureOverlay
    @State private var buildingFacets: [LowPolyBuildings.Facet]
    /// Last settled camera angle; buildings are re-extruded for it.
    @State private var cameraAngle: CameraAngle
    /// MapKit draws same-level overlays in insertion order, so lines/markers are added only after the
    /// low-poly ground is in (otherwise the ground can end up on top of them).
    @State private var linesReady = false

    private static let space = "holeMap"

    init(course: Course, hole: Hole?, shots: [ShotInfo], player: GeoPoint?,
         target: Binding<GeoPoint?> = .constant(nil), pin: GeoPoint? = nil, hazards: [HazardDistance] = [],
         flyoverTrigger: Int = 0, defaultTarget: GeoPoint? = nil,
         onLongPress: ((GeoPoint) -> Void)? = nil, editingPin: Bool = false, onPinMove: ((GeoPoint) -> Void)? = nil,
         animatesHoleChange: Bool = true) {
        self.course = course
        self.hole = hole
        self.shots = shots
        self.player = player
        self._target = target
        self.pin = pin
        self.hazards = hazards
        self.flyoverTrigger = flyoverTrigger
        self.defaultTarget = defaultTarget
        self.onLongPress = onLongPress
        self.editingPin = editingPin
        self.onPinMove = onPinMove
        self.animatesHoleChange = animatesHoleChange
        _position = State(initialValue: Self.position(course: course, hole: hole))
        _overlay = State(initialValue: FeatureOverlay(course: course, hole: hole))
        let scenery = LowPolyScenery(course: course, hole: hole)
        let angle = CameraAngle(hole: hole)
        _scenery = State(initialValue: scenery)
        _cameraAngle = State(initialValue: angle)
        _buildingFacets = State(initialValue: LowPolyBuildings.facets(
            for: scenery.buildings, heading: angle.heading, pitch: angle.pitch))
    }

    private var settings: AppSettings { settingsService.settings }

    private var hasHoleData: Bool {
        guard let hole else { return false }
        return HoleCamera.camera(for: hole) != nil
    }

    private var mapStyle: MapStyle {
        let elevation: MapStyle.Elevation = MapStyleConfig.useRealisticElevation ? .realistic : .flat
        if useSatellite || !hasHoleData { return .imagery(elevation: elevation) }
        return .standard(elevation: elevation, emphasis: .muted, pointsOfInterest: .excludingAll)
    }

    /// Game-like low-poly scenery (default); satellite shows the real imagery instead.
    private var gameStyle: Bool { hasHoleData && !useSatellite }

    private var aimPoint: GeoPoint? { target ?? defaultTarget }
    private var flagPoint: GeoPoint? { dragPin ?? pin ?? hole?.effectiveGreenCenter }
    private var origin: GeoPoint? { player ?? hole?.effectiveTee }

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                // All content above labels: in game mode the low-poly ground hides the basemap's roads,
                // labels and 3D buildings (the standard style is kept because it allows the 2.5D pitch).
                Group {
                    if gameStyle {
                        LowPolyGroundContent(scenery: scenery)
                        FeatureOverlayContent(overlay: overlay, game: true)
                        LowPolyBuildingsContent(facets: buildingFacets)
                        LowPolyTreesContent(scenery: scenery)
                    } else {
                        FeatureOverlayContent(overlay: overlay)
                    }
                    if linesReady {
                        arcs
                        aimContent(proxy: proxy)
                        holeMarkers(proxy: proxy)
                        shotContent
                        hazardContent
                        playerContent
                    }
                }
                .mapOverlayLevel(level: .aboveLabels)
            }
            .mapStyle(mapStyle)
            .mapControls { MapCompass() }
            .coordinateSpace(.named(Self.space))
            .onMapCameraChange(frequency: .onEnd) { ctx in
                let angle = CameraAngle(heading: ctx.camera.heading, pitch: ctx.camera.pitch)
                if angle.differs(from: cameraAngle) { cameraAngle = angle }
            }
            .holeFlyover(hole.map(HoleFlyover.keyframes) ?? [], trigger: flyoverTrigger)
            .id(mapIdentity)
            .onTapGesture { location in
                guard let coord = proxy.convert(location, from: .local) else { return }
                handleTap(GeoPoint(coord))
            }
            .gesture(
                LongPressGesture(minimumDuration: MapStyleConfig.longPressDuration)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        guard case .second(true, let drag?) = value,
                              let coord = proxy.convert(drag.location, from: .local) else { return }
                        onLongPress?(GeoPoint(coord))
                    })
        }
        .overlay(alignment: .topTrailing) { styleToggle }
        .overlay(alignment: .bottomTrailing) { attribution }
        .overlay { noDataOverlay }
        .overlay {
            if showIntro, let hole {
                HoleIntroOverlay(hole: hole, lengthMeters: hole.lengthMeters, settings: settings)
                    .contentShape(Rectangle())
                    .onTapGesture { skipFlyover() }
                    .transition(.opacity)
            }
        }
        .onChange(of: hole?.number) {
            selectedHazard = nil
            let next = Self.position(course: course, hole: hole)
            if animatesHoleChange {
                withAnimation(Motion.standard) { position = next }
            } else {
                // MapKit still glides between cameras when `position` is set directly,
                // so rebuild the map to land on the new hole instantly (hidden by the caller's fade).
                mapIdentity += 1
                position = next
            }
        }
        .onChange(of: hole) {
            scenery = LowPolyScenery(course: course, hole: hole)
            overlay = FeatureOverlay(course: course, hole: hole)
            rebuildBuildings()
            reinsertLines()
        }
        .onChange(of: useSatellite) { reinsertLines() }
        .task { reinsertLines() }
        .onChange(of: cameraAngle) { rebuildBuildings() }
        .onChange(of: flyoverTrigger) {
            guard HoleFlyover.canPlay(hole) else { return }
            withAnimation(Motion.fade) { showIntro = true }
            Task {
                try? await Task.sleep(for: .seconds(HoleFlyover.legDurations.reduce(0, +)))
                withAnimation(Motion.fade) { showIntro = false }
            }
        }
    }

    private func handleTap(_ p: GeoPoint) {
        if let h = hazards.first(where: { PolygonOps.contains(p, in: $0.polygon) }) {
            selectedHazard = selectedHazard == h ? nil : h
            return
        }
        selectedHazard = nil
        if editingPin, let green = hole?.green {
            onPinMove?(PolygonOps.clamp(p, into: green))
            return
        }
        withAnimation(Motion.snappy) { target = p }
        Haptics.play(.selection)
    }

    private func reinsertLines() {
        linesReady = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            linesReady = true
        }
    }

    private func rebuildBuildings() {
        buildingFacets = LowPolyBuildings.facets(
            for: scenery.buildings, heading: cameraAngle.heading, pitch: cameraAngle.pitch)
    }

    private func skipFlyover() {
        withAnimation(Motion.fade) { showIntro = false }
        mapIdentity += 1
        position = Self.position(course: course, hole: hole)
    }

    // MARK: Map content

    @MapContentBuilder private var arcs: some MapContent {
        if settings.distanceArcs, let o = origin, let flag = flagPoint {
            let unit = settings.distanceUnit == .yard ? "y" : "m"
            DistanceArcsOverlay(
                origin: o, facing: flag, radii: settings.arcDistancesMeters,
                labels: [100, 150, 200].map { "\($0)\(unit)" },
                maxRadius: Geo.distance(o, flag) + 20)
        }
    }

    @MapContentBuilder private func aimContent(proxy: MapProxy) -> some MapContent {
        if let o = origin, let aim = aimPoint, let flag = flagPoint {
            MapPolyline(coordinates: [o.coordinate, aim.coordinate, flag.coordinate])
                .stroke(MapPalette.target.opacity(0.85), style: StrokeStyle(lineWidth: MapStyleConfig.targetLineWidth, lineCap: .round))
            Annotation("", coordinate: Geo.midpoint(o, aim).coordinate) {
                MapDistanceLabel(text: settings.format(meters: Geo.distance(o, aim)), emphasized: true)
            }
            Annotation("", coordinate: Geo.midpoint(aim, flag).coordinate) {
                MapDistanceLabel(text: settings.format(meters: Geo.distance(aim, flag)))
            }
            Annotation("", coordinate: aim.coordinate, anchor: .center) {
                TargetMarker()
                    .opacity(target == nil ? 0.6 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                            .onChanged { v in
                                if let c = proxy.convert(v.location, from: .named(Self.space)) { target = GeoPoint(c) }
                            })
                    .onTapGesture(count: 2) { withAnimation(Motion.snappy) { target = nil } }
                    .accessibilityHint("點兩下重設目標")
            }
        }
    }

    @MapContentBuilder private func holeMarkers(proxy: MapProxy) -> some MapContent {
        if let tee = hole?.effectiveTee {
            Annotation("", coordinate: tee.coordinate, anchor: .center) {
                pinBadge(color: MapPalette.tee, label: "T")
            }
        }
        if let flag = flagPoint {
            Annotation("", coordinate: flag.coordinate, anchor: .bottom) {
                PinMarker(isSet: pin != nil, editing: editingPin)
                    .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                        .onChanged { v in
                            guard let c = proxy.convert(v.location, from: .named(Self.space)) else { return }
                            let p = GeoPoint(c)
                            dragPin = hole?.green.map { PolygonOps.clamp(p, into: $0) } ?? p
                        }
                        .onEnded { _ in
                            if let p = dragPin { onPinMove?(p) }
                            dragPin = nil
                        }, including: editingPin ? .all : .subviews)
            }
        }
    }

    @MapContentBuilder private var hazardContent: some MapContent {
        if let h = selectedHazard {
            MapPolygon(coordinates: h.polygon.map(\.coordinate))
                .foregroundStyle(.clear)
                .stroke(Theme.gold, lineWidth: 2)
            Annotation("", coordinate: (PolygonOps.centroid(h.polygon) ?? h.polygon[0]).coordinate) {
                VStack(spacing: 2) {
                    MapDistanceLabel(text: String(localized: "前緣 \(settings.format(meters: h.front))"))
                    MapDistanceLabel(text: String(localized: "飛越 \(settings.format(meters: h.carry))"), emphasized: true)
                }
            }
        }
    }

    @MapContentBuilder private var shotContent: some MapContent {
        let located = locatedShots
        if located.count >= 2 {
            MapPolyline(coordinates: located.map(\.coordinate))
                .stroke(MapPalette.shotLine, lineWidth: MapStyleConfig.shotLineWidth)
        }
        ForEach(located) { item in
            Annotation("", coordinate: item.coordinate, anchor: .center) {
                Text(verbatim: "\(item.number)")
                    .font(.caption2.bold())
                    .foregroundStyle(MapPalette.markerText)
                    .frame(width: MapStyleConfig.markerSize, height: MapStyleConfig.markerSize)
                    .background(MapPalette.shotMarker, in: Circle())
                    .overlay(Circle().stroke(MapPalette.markerRing, lineWidth: 1.5))
                    .accessibilityLabel("第 \(item.number) 桿")
            }
        }
        ForEach(segmentLabels) { label in
            Annotation("", coordinate: label.coordinate, anchor: .center) {
                MapDistanceLabel(text: settings.format(meters: label.meters))
            }
        }
    }

    @MapContentBuilder private var playerContent: some MapContent {
        if let player {
            Annotation("", coordinate: player.coordinate, anchor: .center) {
                Circle()
                    .fill(MapPalette.player)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(MapPalette.markerRing, lineWidth: 2.5))
                    .shadow(radius: 2)
                    .accessibilityLabel("你的位置")
            }
        } else {
            UserAnnotation()
        }
    }

    // MARK: Overlays

    private var styleToggle: some View {
        Picker("底圖", selection: $useSatellite) {
            Text("遊戲").tag(false)
            Text("衛星").tag(true)
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerTiny))
        .padding(8)
        .opacity(hasHoleData ? 1 : 0)
    }

    private var attribution: some View {
        Text(GolfKit.mapAttribution)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.trailing, 8)
            .padding(.bottom, 4)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var noDataOverlay: some View {
        if !hasHoleData {
            Text("此洞無圖資，可前往編輯")
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .allowsHitTesting(false)
        }
    }

    private func pinBadge(color: Color, label: String) -> some View {
        Text(verbatim: label)
            .font(.caption2.bold())
            .foregroundStyle(MapPalette.markerText)
            .frame(width: 20, height: 20)
            .background(color, in: Circle())
            .overlay(Circle().stroke(MapPalette.markerRing, lineWidth: 1.5))
            .accessibilityLabel("發球台")
    }

    // MARK: Derived data

    private struct ShotMarker: Identifiable {
        let id: UUID
        let number: Int
        let coordinate: CLLocationCoordinate2D
        let point: GeoPoint
    }

    private struct SegmentLabel: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let meters: Double
    }

    private var locatedShots: [ShotMarker] {
        shots.enumerated().compactMap { index, shot in
            guard let loc = shot.location else { return nil }
            return ShotMarker(id: shot.id, number: index + 1, coordinate: loc.coordinate, point: loc)
        }
    }

    private var segmentLabels: [SegmentLabel] {
        let located = locatedShots
        return zip(located, located.dropFirst()).map { a, b in
            SegmentLabel(
                id: a.id, coordinate: Geo.midpoint(a.point, b.point).coordinate,
                meters: Geo.distance(a.point, b.point))
        }
    }

    private static func position(course: Course, hole: Hole?) -> MapCameraPosition {
        if let hole, let camera = HoleCamera.camera(for: hole) { return .camera(camera) }
        return .camera(HoleCamera.fallbackCamera(for: course))
    }
}

/// Camera heading/pitch, compared loosely so tiny drifts don't rebuild the buildings.
struct CameraAngle: Equatable {
    var heading: Double
    var pitch: Double

    init(heading: Double, pitch: Double) {
        self.heading = heading
        self.pitch = pitch
    }

    init(hole: Hole?) {
        let camera = hole.flatMap(HoleCamera.camera(for:))
        self.init(heading: camera?.heading ?? 0, pitch: camera?.pitch ?? MapStyleConfig.pitch)
    }

    func differs(from other: CameraAngle) -> Bool {
        let dh = abs((heading - other.heading + 540).truncatingRemainder(dividingBy: 360) - 180)
        return dh > 2 || abs(pitch - other.pitch) > 2
    }
}
