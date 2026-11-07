import Foundation
import GolfKit

/// Owns a `SwingDetector` and serialises access with a lock so it can be fed from the
/// motion `OperationQueue` (off the main actor). Only resulting `SwingEvent`s leave this type.
final class SwingDetectionPipeline: @unchecked Sendable {
    private let lock = NSLock()
    private let detector: SwingDetector

    init(config: SwingDetectorConfig = .default) {
        detector = SwingDetector(config: config)
    }

    func ingest(_ sample: MotionSample) -> SwingEvent? {
        lock.lock()
        defer { lock.unlock() }
        return detector.ingest(sample)
    }

    func configure(sensitivity: Double) {
        lock.lock()
        defer { lock.unlock() }
        var c = detector.config
        c.sensitivity = sensitivity
        detector.config = c
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        detector.reset()
    }
}
