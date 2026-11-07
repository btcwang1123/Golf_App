import Foundation
import GolfKit
import WatchKit

/// Event-sourced round state for the watch. Same surface as the iPhone `RoundStore`.
@MainActor @Observable
final class WatchRoundStore {
    struct Toast: Equatable, Identifiable {
        /// The auto-recorded swing stroke this toast can undo.
        var id: UUID
        var hole: Int
        var seconds: Int
        /// Backswing : downswing of the detected swing.
        var tempo: Double?
    }

    struct AdvanceBanner: Equatable, Identifiable {
        var id = UUID()
        var from: Int
        var to: Int
    }

    private struct Persisted: Codable {
        var roundId: UUID
        var courseId: String
        var events: [RoundEvent]
    }

    private static let fileName = "active_round.json"

    private(set) var events: [RoundEvent] = []
    private(set) var active: RoundState?
    private(set) var activeCourse: Course?
    private(set) var roundId: UUID?
    private(set) var courseId: String?
    private(set) var recentCourses: [WatchCourseCache.Summary] = []
    private(set) var toast: Toast?
    private(set) var advanceBanner: AdvanceBanner?
    /// Hazards ahead, recomputed every 3 s or 3 m (T46).
    private(set) var hazards: [HazardDistance] = []
    @ObservationIgnored private var hazardOrigin: GeoPoint?
    @ObservationIgnored private var hazardsAt: Date = .distantPast
    @ObservationIgnored private let complication = ComplicationService()
    static let hazardRefreshSeconds: TimeInterval = 3
    static let hazardRefreshMeters = 3.0

    /// Called with every locally appended event (for sync).
    @ObservationIgnored var onEventsAppended: (@MainActor ([RoundEvent]) -> Void)?
    /// Called when a round is started on the watch itself.
    @ObservationIgnored var onRoundStarted: (@MainActor (UUID, String) -> Void)?
    /// Called when a round references a course that is not cached.
    @ObservationIgnored var onCourseNeeded: (@MainActor (String) -> Void)?

    @ObservationIgnored private let settings: WatchSettingsService
    @ObservationIgnored private let location: WatchLocationService
    @ObservationIgnored private let workout: WorkoutService
    @ObservationIgnored private let monitor: SwingMonitor
    @ObservationIgnored private let cache: WatchCourseCache
    @ObservationIgnored private let config: WatchRoundConfig
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var suppressedAdvanceHole: Int?

    init(
        settings: WatchSettingsService, location: WatchLocationService, workout: WorkoutService,
        monitor: SwingMonitor, cache: WatchCourseCache = WatchCourseCache(),
        config: WatchRoundConfig = .default
    ) {
        self.settings = settings
        self.location = location
        self.workout = workout
        self.monitor = monitor
        self.cache = cache
        self.config = config
        self.fileURL = WatchCourseCache.appSupport().appendingPathComponent(Self.fileName)

        monitor.onSwing = { [weak self] event, fix in self?.handleSwing(event, location: fix) }
        location.onUpdate = { [weak self] point in self?.handleLocation(point) }
        refreshRecentCourses()
        restore()
    }

    // MARK: - Derived

    var currentHoleNumber: Int { active?.currentHole ?? 1 }
    var currentHoleState: HoleState { active?.hole(currentHoleNumber) ?? HoleState(number: currentHoleNumber) }
    var currentHole: Hole? { activeCourse?.hole(currentHoleNumber) }
    var par: Int? { currentHoleState.par ?? currentHole?.par }
    var totalStrokes: Int { active?.totalStrokes ?? 0 }
    var maxHole: Int { activeCourse?.holes.map(\.number).max() ?? config.defaultHoleCount }

    var pin: GeoPoint? { active?.pin(for: currentHoleNumber) }

    var greenDistances: (front: Double, center: Double, back: Double)? {
        guard let p = location.current, let hole = currentHole else { return nil }
        return hole.distancesMeters(from: p, pin: pin)
    }

    /// Where the big number points: pin, else green center.
    var flag: GeoPoint? { pin ?? currentHole?.effectiveGreenCenter }

    func setPin(_ preset: PinPreset) {
        guard let presets = currentHole?.pinPresets() else { return }
        let p: GeoPoint
        switch preset {
        case .front: p = presets.front
        case .center: p = presets.center
        case .back: p = presets.back
        }
        append(.setPin(hole: currentHoleNumber, location: p))
    }

    enum PinPreset: CaseIterable { case front, center, back }

    func refreshHazards(force: Bool = false) {
        guard let hole = currentHole else { hazards = []; return }
        let origin = location.current ?? hole.effectiveTee
        let now = Date()
        if !force, let o = hazardOrigin, let origin, now.timeIntervalSince(hazardsAt) < Self.hazardRefreshSeconds,
           Geo.distance(o, origin) < Self.hazardRefreshMeters {
            return
        }
        guard let origin else { hazards = []; return }
        hazardOrigin = origin
        hazardsAt = now
        hazards = HazardDistances.compute(from: origin, hole: hole, target: flag, extraFeatures: activeCourse?.features ?? [])
    }

    var isOnGreen: Bool {
        guard let p = location.current, let green = currentHole?.green else { return false }
        return PolygonOps.contains(p, in: green)
    }

    /// Explanation shown when sensors are unavailable; manual buttons keep working.
    var sensorWarning: String? {
        if location.isDenied { return "未允許定位，無法顯示距離；仍可手動記桿。" }
        return workout.authorizationDenied
    }

    // MARK: - Round lifecycle

    func refreshRecentCourses() {
        recentCourses = cache.summaries(limit: config.recentCoursesLimit)
    }

    func start(course: Course, roundId: UUID = UUID()) {
        cache.save(course)
        refreshRecentCourses()
        resetRound(roundId: roundId, courseId: course.id, course: course)
        startSensors()
        onRoundStarted?(roundId, course.id)
        append(.start(courseId: course.id))
    }

    /// Joins a round started elsewhere. Returns false when the course is not cached yet
    /// (`onCourseNeeded` is then invoked).
    @discardableResult
    func adopt(roundId: UUID, courseId: String) -> Bool {
        if self.roundId == roundId {
            if activeCourse == nil, let c = cache.load(id: courseId) {
                activeCourse = c
                recompute()
            }
            return activeCourse != nil
        }
        let course = cache.load(id: courseId)
        resetRound(roundId: roundId, courseId: courseId, course: course)
        startSensors()
        if course == nil { onCourseNeeded?(courseId) }
        return course != nil
    }

    func cacheCourse(_ course: Course) {
        cache.save(course)
        refreshRecentCourses()
        if course.id == courseId {
            activeCourse = course
            recompute()
        }
    }

    func start(courseId id: String) {
        guard let course = cache.load(id: id) else { return }
        start(course: course)
    }

    @discardableResult
    func append(_ kind: RoundEvent.Kind) -> RoundEvent {
        let event = RoundEvent.make(roundId: roundId ?? UUID(), source: .watch, kind: kind)
        guard roundId != nil else { return event }
        events.append(event)
        recompute()
        persist()
        onEventsAppended?([event])
        if case .end = kind { finishRound() }
        return event
    }

    func merge(_ incoming: [RoundEvent]) {
        if roundId == nil || !incoming.contains(where: { $0.roundId == roundId }) {
            // A round started on the phone whose `.startRound` hasn't arrived yet:
            // join it from its own `.start` event (unless it has already ended).
            let ended = Set(incoming.compactMap { e -> UUID? in
                if case .end = e.kind { return e.roundId } else { return nil }
            })
            if let start = incoming.first(where: {
                if case .start = $0.kind { return !ended.contains($0.roundId) } else { return false }
            }), start.roundId != roundId, case .start(let courseId) = start.kind {
                adopt(roundId: start.roundId, courseId: courseId)
            }
        }
        guard let roundId else { return }
        let relevant = incoming.filter { $0.roundId == roundId }
        guard !relevant.isEmpty else { return }
        events = RoundReducer.merge(events, relevant)
        recompute()
        persist()
        if active?.isEnded == true { finishRound() }
    }

    func end() {
        guard roundId != nil else { return }
        append(.end)
    }

    // MARK: - Actions

    func addStroke(_ type: RoundEvent.StrokeType) {
        let fix = location.recentFix(maxAge: config.fixMaxAge, maxAccuracy: config.fixMaxAccuracy)
        append(.stroke(hole: currentHoleNumber, type: type, location: fix, swing: nil))
    }

    func removeLastStroke() {
        guard let id = currentHoleState.shots.last?.id else { return }
        append(.void(strokeId: id))
        if toast?.id == id { toast = nil }
    }

    func nextHole() {
        guard currentHoleNumber < maxHole else { return }
        append(.goToHole(currentHoleNumber + 1))
    }

    func previousHole() {
        guard currentHoleNumber > 1 else { return }
        append(.goToHole(currentHoleNumber - 1))
    }

    func undoToast() {
        guard let toast else { return }
        append(.void(strokeId: toast.id))
        dismissToast()
    }

    func penaltyToast() {
        guard let toast else { return }
        append(.penalty(hole: toast.hole, count: 1))
        dismissToast()
    }

    func dismissToast() {
        toastTask?.cancel()
        toast = nil
    }

    func undoAdvance() {
        guard let banner = advanceBanner else { return }
        suppressedAdvanceHole = banner.from
        append(.goToHole(banner.from))
        dismissBanner()
    }

    func dismissBanner() {
        bannerTask?.cancel()
        advanceBanner = nil
    }

    // MARK: - Sensor callbacks

    private func handleSwing(_ swing: SwingEvent, location fix: GeoPoint?) {
        guard let active, !active.isEnded else { return }
        let hole = active.currentHole
        let stroke = append(.stroke(hole: hole, type: .swing, location: fix, swing: swing.metrics))
        haptic(.success)
        let configured = settings.settings.undoWindowSeconds
        let seconds = configured > 0 ? configured : config.fallbackToastSeconds
        toast = Toast(id: stroke.id, hole: hole, seconds: seconds, tempo: swing.metrics.tempo)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if self?.toast?.id == stroke.id { self?.toast = nil }
        }
    }

    private func handleLocation(_ point: GeoPoint) {
        if active != nil { refreshHazards() }
        guard settings.settings.autoAdvanceHole, let active, !active.isEnded,
              let course = activeCourse else { return }
        let current = active.currentHole
        if let suppressed = suppressedAdvanceHole {
            if suppressed == current { return }
            suppressedAdvanceHole = nil
        }
        let state = active.hole(current) ?? HoleState(number: current)
        guard let next = HoleAdvanceDetector.suggest(current: current, location: point, state: state, course: course)
        else { return }
        append(.goToHole(next))
        haptic(.directionUp)
        let banner = AdvanceBanner(from: current, to: next)
        advanceBanner = banner
        bannerTask?.cancel()
        bannerTask = Task { [weak self, seconds = config.advanceBannerSeconds] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if self?.advanceBanner?.id == banner.id { self?.advanceBanner = nil }
        }
    }

    // MARK: - Internals

    private func haptic(_ type: WKHapticType) {
        guard settings.settings.hapticsOn else { return }
        WKInterfaceDevice.current().play(type)
    }

    private func resetRound(roundId: UUID, courseId: String, course: Course?) {
        stopSensors()
        dismissToast()
        dismissBanner()
        suppressedAdvanceHole = nil
        self.roundId = roundId
        self.courseId = courseId
        self.activeCourse = course
        self.events = []
        recompute()
        persist()
    }

    private func recompute() {
        guard let roundId else {
            active = nil
            return
        }
        var state = RoundReducer.reduce(events, course: activeCourse)
        state.roundId = roundId
        if state.courseId == nil { state.courseId = courseId }
        let holeChanged = active?.currentHole != state.currentHole
        active = state
        if holeChanged { refreshHazards(force: true) }
        let n = state.currentHole
        let target = state.pin(for: n) ?? activeCourse?.hole(n)?.effectiveGreenCenter
        let d = zip2(location.current, target).map { Geo.distance($0, $1) }
        complication.update(hole: n, strokes: state.totalStrokes, distanceToPin: d, unit: settings.settings.distanceUnit)
    }

    private func finishRound() {
        stopSensors()
        dismissToast()
        dismissBanner()
        roundId = nil
        courseId = nil
        active = nil
        activeCourse = nil
        events = []
        hazards = []
        complication.clear()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func startSensors() {
        location.start()
        monitor.start(settings: settings.settings)
        Task { await workout.start() }
    }

    private func stopSensors() {
        monitor.stop()
        location.stop()
        Task { await workout.end() }
    }

    private func persist() {
        guard let roundId, let courseId else { return }
        let payload = Persisted(roundId: roundId, courseId: courseId, events: events)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func restore() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        roundId = saved.roundId
        courseId = saved.courseId
        events = saved.events
        activeCourse = cache.load(id: saved.courseId)
        recompute()
        if active?.isEnded == true {
            finishRound()
            return
        }
        startSensors()
    }
}

private func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
