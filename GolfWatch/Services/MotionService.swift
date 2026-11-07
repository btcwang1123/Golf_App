import CoreMotion
import Foundation
import GolfKit

/// Streams device motion at 100 Hz as `MotionSample`s on a private serial queue.
/// Wrist handling: the watch X axis is mirrored (negated) when worn on the RIGHT wrist,
/// so that data always looks like a left-wrist recording.
@MainActor @Observable
final class MotionService {
    static let updateInterval: TimeInterval = 1.0 / 100.0

    private(set) var isRunning = false
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "golf.motion"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    /// `sink` is called on the motion queue (not the main actor).
    func start(wrist: AppSettings.Wrist, sink: @escaping @Sendable (MotionSample) -> Void) {
        stop()
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = Self.updateInterval
        manager.startDeviceMotionUpdates(
            to: queue,
            withHandler: Self.makeHandler(mirrorX: wrist == .right, sink: sink))
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }

    nonisolated private static func makeHandler(
        mirrorX: Bool, sink: @escaping @Sendable (MotionSample) -> Void
    ) -> @Sendable (CMDeviceMotion?, Error?) -> Void {
        let sign: Double = mirrorX ? -1 : 1
        return { motion, _ in
            guard let m = motion else { return }
            let rr = m.rotationRate
            let ua = m.userAcceleration
            sink(MotionSample(
                t: m.timestamp,
                rotationRate: SIMD3(rr.x * sign, rr.y, rr.z),
                userAccel: SIMD3(ua.x * sign, ua.y, ua.z)))
        }
    }
}
