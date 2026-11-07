import Foundation
import GolfKit

/// Motion -> detector (off-main) -> `lastSwing`, attaching a recent GPS fix.
@MainActor @Observable
final class SwingMonitor {
    private(set) var lastSwing: SwingEvent?
    private(set) var isDetecting = false
    @ObservationIgnored var onSwing: (@MainActor (SwingEvent, GeoPoint?) -> Void)?
    /// While set (range practice), swings go here instead of the round.
    @ObservationIgnored var onPracticeSwing: (@MainActor (SwingEvent) -> Void)?

    @ObservationIgnored private let motion: MotionService
    @ObservationIgnored private let location: WatchLocationService
    @ObservationIgnored private let pipeline = SwingDetectionPipeline()
    @ObservationIgnored private let config: WatchRoundConfig
    @ObservationIgnored private var wrist: AppSettings.Wrist = .left

    init(motion: MotionService, location: WatchLocationService, config: WatchRoundConfig = .default) {
        self.motion = motion
        self.location = location
        self.config = config
    }

    func start(settings: AppSettings) {
        wrist = settings.wrist
        pipeline.configure(sensitivity: settings.swingSensitivity)
        pipeline.reset()
        launch()
    }

    func stop() {
        motion.stop()
        isDetecting = false
    }

    /// Applies sensitivity immediately; restarts sampling if the wrist changed.
    func apply(settings: AppSettings) {
        pipeline.configure(sensitivity: settings.swingSensitivity)
        if settings.wrist != wrist {
            wrist = settings.wrist
            if isDetecting { launch() }
        }
    }

    private func launch() {
        let pipeline = pipeline
        motion.start(wrist: wrist) { [weak self] sample in
            guard let event = pipeline.ingest(sample) else { return }
            Task { @MainActor in self?.handle(event) }
        }
        isDetecting = motion.isRunning
    }

    private func handle(_ event: SwingEvent) {
        lastSwing = event
        if let practice = onPracticeSwing {
            practice(event)
            return
        }
        let fix = location.recentFix(maxAge: config.fixMaxAge, maxAccuracy: config.fixMaxAccuracy)
        onSwing?(event, fix)
    }
}
