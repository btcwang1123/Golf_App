import Foundation
import GolfKit
import WatchKit

/// Driving-range mode: counts swings and their tempo without a round, then sends the session to the phone.
@MainActor @Observable
final class WatchPracticeStore {
    private(set) var session: PracticeSession?
    /// Summary of the session that just ended.
    private(set) var finished: PracticeSession?
    var club: Club? = .i7 {
        didSet { session?.club = club }
    }

    @ObservationIgnored var onFinished: (@MainActor (PracticeSession) -> Void)?
    @ObservationIgnored private let monitor: SwingMonitor
    @ObservationIgnored private let workout: WorkoutService
    @ObservationIgnored private let settings: WatchSettingsService
    @ObservationIgnored private let fileURL = WatchCourseCache.appSupport().appendingPathComponent("practice.json")

    init(monitor: SwingMonitor, workout: WorkoutService, settings: WatchSettingsService) {
        self.monitor = monitor
        self.workout = workout
        self.settings = settings
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode(PracticeSession.self, from: data) {
            session = saved
            club = saved.club
            attach()
        }
    }

    var isActive: Bool { session != nil }
    var lastTempo: Double? { session?.swings.last.map(\.metrics.tempo).flatMap { TempoStats.plausible.contains($0) ? $0 : nil } }
    var stats: TempoStats { session?.tempo ?? TempoStats.make([]) }

    func start() {
        guard session == nil else { return }
        finished = nil
        session = PracticeSession(startedAt: Date(), club: club)
        attach()
        persist()
    }

    func undoLast() {
        guard session?.swings.isEmpty == false else { return }
        session?.swings.removeLast()
        persist()
    }

    func end() {
        guard var s = session else { return }
        s.endedAt = Date()
        monitor.onPracticeSwing = nil
        monitor.stop()
        Task { await workout.end() }
        session = nil
        try? FileManager.default.removeItem(at: fileURL)
        guard !s.swings.isEmpty else { return }
        finished = s
        onFinished?(s)
    }

    func clearSummary() { finished = nil }

    private func attach() {
        monitor.onPracticeSwing = { [weak self] event in self?.record(event) }
        monitor.start(settings: settings.settings)
        Task { await workout.start() }
    }

    private func record(_ event: SwingEvent) {
        guard session != nil else { return }
        session?.swings.append(.init(timestamp: Date(), metrics: event.metrics, club: club))
        WKInterfaceDevice.current().play(.click)
        persist()
    }

    private func persist() {
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
