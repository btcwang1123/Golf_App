import Foundation
import GolfKit
import Observation

@MainActor @Observable
final class EditorModel {
    enum Tool: String, CaseIterable, Identifiable {
        case tee, greenCenter, green, fairway, bunker, water, outOfBounds, edit
        var id: String { rawValue }

        var title: String {
            switch self {
            case .tee: "發球台"
            case .greenCenter: "果嶺中心"
            case .green: "果嶺"
            case .fairway: "球道"
            case .bunker: "沙坑"
            case .water: "水"
            case .outOfBounds: "OB"
            case .edit: "調整"
            }
        }

        var isPolygon: Bool { featureKind != nil }

        var featureKind: Feature.Kind? {
            switch self {
            case .green: .green
            case .fairway: .fairway
            case .bunker: .bunker
            case .water: .water
            case .outOfBounds: .outOfBounds
            case .tee, .greenCenter, .edit: nil
            }
        }

        /// Tool that fixes a missing checklist item.
        init?(item: HoleQuality.Item) {
            switch item {
            case .tee: self = .tee
            case .greenCenter: self = .greenCenter
            case .greenPolygon: self = .green
            case .fairway: self = .fairway
            case .hazards: self = .bunker
            case .par, .handicap: return nil
            }
        }
    }

    static let minPolygonPoints = 3
    static let defaultPar = 4
    static let maxUndo = 100
    /// New points closer than this (m) to an existing vertex snap onto it.
    static let snapMeters = 2.0

    private(set) var course: Course
    var currentHoleNumber: Int
    var tool: Tool = .tee {
        didSet { if oldValue != tool { draftPolygon = []; selectedFeature = nil } }
    }
    private(set) var draftPolygon: [GeoPoint] = []
    /// Feature (index into the current hole's features) whose vertices are being edited.
    var selectedFeature: Int?
    /// Vertex being dragged, for the magnifier.
    private(set) var dragging: GeoPoint?
    private let isNew: Bool
    private var snapshots: [Course] = []
    /// Geometry was drawn by hand on imagery (not distributable).
    private var traced = false
    /// Geometry was measured on site with GPS.
    private var surveyed = false
    /// Holes whose tee was estimated from the fairways (re-estimated when the green moves).
    private(set) var autoTeeHoles: Set<Int> = []
    /// Result of the last one-tap green placement, for the hint line.
    private(set) var lastAutoLayout: AutoLayoutResult?

    enum AutoLayoutResult: Equatable {
        case placed(hole: Int, meters: Double, par: Int)
        case needsTee(hole: Int)
    }

    init(course: Course, isNew: Bool) {
        self.course = course
        self.isNew = isNew
        self.currentHoleNumber = course.holes.first?.number ?? 1
        surveyed = course.provenance == .survey
        // Courses without any hole positions start with the one-tap green tool.
        if !course.hasHoleMaps { tool = .greenCenter }
    }

    /// Adds `count` empty holes to a course that has none (e.g. an OSM course with only outlines).
    static func withHoles(_ course: Course, count: Int) -> Course {
        guard course.holes.isEmpty else { return course }
        var c = course
        c.holes = (1...max(1, count)).map { Hole(number: $0, par: defaultPar) }
        return c
    }

    static func newCourse(name: String, holeCount: Int, center: GeoPoint) -> Course {
        let holes = (1...max(1, holeCount)).map { Hole(number: $0, par: defaultPar) }
        return Course(id: "user-\(UUID().uuidString)", name: name, center: center, holes: holes, source: .user)
    }

    var canUndo: Bool { !snapshots.isEmpty }

    var currentHole: Hole? { course.hole(currentHoleNumber) }

    private var holeIndex: Int? { course.holes.firstIndex { $0.number == currentHoleNumber } }

    // MARK: Quality

    var holeQuality: HoleQuality? { currentHole.map { HoleQuality.evaluate($0) } }

    /// Per item: true when present.
    var checklist: [HoleQuality.Item: Bool] {
        guard let q = holeQuality else { return [:] }
        return Dictionary(uniqueKeysWithValues: HoleQuality.Item.allCases.map { ($0, !q.missing.contains($0)) })
    }

    var completion: Double { CourseQuality.evaluate(course).score }

    /// Next hole after the current one (wrapping) missing a required item.
    var nextIncompleteHole: Int? {
        let numbers = course.holes.map(\.number).sorted()
        guard let i = numbers.firstIndex(of: currentHoleNumber) else { return nil }
        let order = Array(numbers[(i + 1)...]) + Array(numbers[...i])
        return order.first { n in course.hole(n).map { !HoleQuality.evaluate($0).isComplete } ?? false }
    }

    func focus(on item: HoleQuality.Item) {
        if let t = Tool(item: item) { tool = t }
    }

    // MARK: Hole selection

    func selectHole(_ number: Int) {
        currentHoleNumber = number
        draftPolygon = []
        selectedFeature = nil
    }

    // MARK: Drawing

    func tap(at point: GeoPoint) {
        let p = snapped(point)
        switch tool {
        case .tee:
            traced = true
            autoTeeHoles.remove(currentHoleNumber)
            mutateHole { h in
                h.tee = p
                if let g = h.greenCenter, h.path.count < 3 { h.path = [p, g] }
            }
            if case .needsTee(let n) = lastAutoLayout, n == currentHoleNumber {
                lastAutoLayout = nil
                tool = .greenCenter
                let numbers = course.holes.map(\.number).sorted()
                if let next = numbers.first(where: { $0 > n && course.hole($0)?.greenCenter == nil }) { selectHole(next) }
            }
        case .greenCenter:
            traced = true
            placeGreen(p)
        case .edit:
            selectFeature(containing: point)
        default:
            draftPolygon.append(p)
        }
    }

    /// Sets the green center and, unless the user placed the tee, estimates tee / length / par
    /// from the fairways, then moves on to the next hole still missing its green.
    private func placeGreen(_ green: GeoPoint) {
        let number = currentHoleNumber
        guard let hole = currentHole else { return }
        let teeIsAuto = hole.tee == nil || autoTeeHoles.contains(number)
        let fairways = (course.features + hole.features).filter { $0.kind == .fairway }.map(\.polygon)
        let tee = teeIsAuto ? HoleAutoLayout.estimateTee(green: green, fairways: fairways) : hole.tee
        mutateHole { h in
            h.greenCenter = green
            if teeIsAuto, let tee {
                h.tee = tee
                h.path = [tee, green]
                h.par = HoleAutoLayout.guessPar(lengthMeters: Geo.distance(tee, green))
            } else if let t = h.tee, h.path.count < 3 {
                h.path = [t, green]
            }
        }
        guard let tee else {
            lastAutoLayout = .needsTee(hole: number)
            tool = .tee
            return
        }
        if teeIsAuto { autoTeeHoles.insert(number) }
        let meters = Geo.distance(tee, green)
        lastAutoLayout = .placed(hole: number, meters: meters, par: currentHole?.par ?? HoleAutoLayout.guessPar(lengthMeters: meters))
        let numbers = course.holes.map(\.number).sorted()
        if let next = numbers.first(where: { $0 > number && course.hole($0)?.greenCenter == nil }) {
            selectHole(next)
        }
    }

    /// Existing vertex within `snapMeters`, else the point itself.
    func snapped(_ p: GeoPoint) -> GeoPoint {
        var candidates = draftPolygon
        if let hole = currentHole {
            candidates += hole.features.flatMap(\.polygon)
            candidates += [hole.tee, hole.greenCenter].compactMap { $0 }
        }
        let best = candidates.min { Geo.distance($0, p) < Geo.distance($1, p) }
        if let best, Geo.distance(best, p) < Self.snapMeters { return best }
        return p
    }

    func removeLastDraftPoint() {
        if !draftPolygon.isEmpty { draftPolygon.removeLast() }
    }

    func cancelDraft() { draftPolygon = [] }

    func closePolygon() {
        guard let kind = tool.featureKind, draftPolygon.count >= Self.minPolygonPoints else { return }
        traced = true
        addFeature(Feature(kind: kind, polygon: draftPolygon))
        draftPolygon = []
    }

    private func addFeature(_ f: Feature) {
        mutateHole { hole in
            hole.features.append(f)
            if f.kind == .green {
                hole.green = f.polygon
                if hole.greenCenter == nil { hole.greenCenter = PolygonOps.centroid(f.polygon) }
            }
        }
    }

    func deleteFeature(at index: Int) {
        guard let hole = currentHole, hole.features.indices.contains(index) else { return }
        if selectedFeature == index { selectedFeature = nil }
        mutateHole { hole in
            let removed = hole.features.remove(at: index)
            if removed.kind == .green, hole.green == removed.polygon {
                hole.green = hole.features.last { $0.kind == .green }?.polygon
            }
        }
    }

    // MARK: Vertex editing

    private func selectFeature(containing p: GeoPoint) {
        guard let hole = currentHole else { return }
        selectedFeature = hole.features.indices.last { PolygonOps.contains(p, in: hole.features[$0].polygon) }
    }

    /// Begin a vertex drag (pushes one undo snapshot for the whole drag).
    func beginDrag() { pushSnapshot() }

    func moveVertex(polygon: Int, index: Int, to point: GeoPoint, final: Bool = false) {
        guard let hi = holeIndex, course.holes[hi].features.indices.contains(polygon),
              course.holes[hi].features[polygon].polygon.indices.contains(index) else { return }
        traced = true
        dragging = final ? nil : point
        let target = final ? snappedExcluding(point, polygon: polygon, index: index) : point
        updateFeature(hi, polygon) { $0[index] = target }
    }

    func insertVertex(polygon: Int, after index: Int, at point: GeoPoint) {
        guard let hi = holeIndex, course.holes[hi].features.indices.contains(polygon) else { return }
        pushSnapshot()
        traced = true
        updateFeature(hi, polygon) { poly in
            let at = min(index + 1, poly.count)
            poly.insert(point, at: at)
        }
    }

    func deleteVertex(polygon: Int, index: Int) {
        guard let hi = holeIndex, course.holes[hi].features.indices.contains(polygon),
              course.holes[hi].features[polygon].polygon.count > Self.minPolygonPoints else { return }
        pushSnapshot()
        updateFeature(hi, polygon) { $0.remove(at: index) }
    }

    private func snappedExcluding(_ p: GeoPoint, polygon: Int, index: Int) -> GeoPoint {
        guard let hole = currentHole else { return p }
        var others: [GeoPoint] = []
        for (fi, f) in hole.features.enumerated() {
            for (vi, v) in f.polygon.enumerated() where !(fi == polygon && vi == index) { others.append(v) }
        }
        let best = others.min { Geo.distance($0, p) < Geo.distance($1, p) }
        if let best, Geo.distance(best, p) < Self.snapMeters { return best }
        return p
    }

    /// Mutates a feature polygon and keeps `hole.green` in sync for green features (no snapshot).
    private func updateFeature(_ hi: Int, _ fi: Int, _ change: (inout Polygon) -> Void) {
        let old = course.holes[hi].features[fi].polygon
        var poly = old
        change(&poly)
        course.holes[hi].features[fi].polygon = poly
        if course.holes[hi].features[fi].kind == .green, course.holes[hi].green == old {
            course.holes[hi].green = poly
        }
    }

    /// Copies all features of another hole into the current one (e.g. shared fairway / water).
    func copyFeatures(fromHole number: Int) {
        guard let src = course.hole(number), number != currentHoleNumber, !src.features.isEmpty else { return }
        traced = true
        mutateHole { hole in
            for f in src.features where !hole.features.contains(f) { hole.features.append(f) }
        }
    }

    // MARK: Hole attributes

    func setPar(_ par: Int) {
        mutateHole { $0.par = par }
    }

    func setHandicap(_ hcp: Int?) {
        mutateHole { $0.handicap = hcp }
    }

    // MARK: Survey (GPS-measured, distributable)

    func applySurveyTee(_ p: GeoPoint) {
        surveyed = true
        mutateHole { $0.tee = p; Self.autoPath(&$0) }
    }

    func applySurveyGreenCenter(_ p: GeoPoint) {
        surveyed = true
        mutateHole { $0.greenCenter = p; Self.autoPath(&$0) }
    }

    /// Front / back marks: when no green outline was walked, an estimated oval is derived from them.
    func applySurveyGreenFrontBack(front: GeoPoint?, back: GeoPoint?) {
        guard let front, let back else { return }
        surveyed = true
        mutateHole { hole in
            guard hole.green == nil else { return }
            let center = hole.greenCenter ?? Geo.midpoint(front, back)
            let depth = Geo.distance(front, back)
            let bearing = Geo.bearing(front, back)
            let halfW = depth * 0.4, halfD = depth / 2
            let ring: Polygon = (0..<12).map { i in
                let a = Double(i) / 12 * 2 * .pi
                let x = sin(a) * halfW, y = cos(a) * halfD
                let b = bearing * .pi / 180
                return Geo.unproject(x: x * cos(b) + y * sin(b), y: -x * sin(b) + y * cos(b), origin: center)
            }
            hole.green = ring
            hole.features.append(Feature(kind: .green, polygon: ring))
            if hole.greenCenter == nil { hole.greenCenter = center }
            Self.autoPath(&hole)
        }
    }

    func applySurveyGreen(_ polygon: Polygon) {
        surveyed = true
        mutateHole { hole in
            hole.features.removeAll { $0.kind == .green && $0.polygon == hole.green }
            hole.green = polygon
            hole.features.append(Feature(kind: .green, polygon: polygon))
            if hole.greenCenter == nil { hole.greenCenter = PolygonOps.centroid(polygon) }
            Self.autoPath(&hole)
        }
    }

    private static func autoPath(_ hole: inout Hole) {
        if let t = hole.tee, let g = hole.greenCenter, hole.path.count < 3 { hole.path = [t, g] }
    }

    func undo() {
        guard let last = snapshots.popLast() else { return }
        course = last
        if course.hole(currentHoleNumber) == nil { currentHoleNumber = course.holes.first?.number ?? 1 }
        draftPolygon = []
        selectedFeature = nil
    }

    func finalizedCourse() -> Course {
        var result = course
        result.source = .user
        result.provenance = traced ? .userTraced : (surveyed ? .survey : course.provenance ?? .userTraced)
        for i in result.holes.indices {
            let hole = result.holes[i]
            if hole.path.isEmpty, let tee = hole.tee, let green = hole.greenCenter {
                result.holes[i].path = [tee, green]
            }
        }
        if isNew {
            let tees = result.holes.compactMap(\.tee)
            if !tees.isEmpty {
                result.center = GeoPoint(
                    lat: tees.map(\.lat).reduce(0, +) / Double(tees.count),
                    lon: tees.map(\.lon).reduce(0, +) / Double(tees.count))
            }
        }
        return result
    }

    private func mutateHole(_ change: (inout Hole) -> Void) {
        guard let i = holeIndex else { return }
        pushSnapshot()
        change(&course.holes[i])
    }

    private func pushSnapshot() {
        snapshots.append(course)
        if snapshots.count > Self.maxUndo { snapshots.removeFirst() }
    }
}
