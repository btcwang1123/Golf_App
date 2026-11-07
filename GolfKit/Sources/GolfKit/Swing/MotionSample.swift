import Foundation

/// One device-motion reading. Rotation rate is in rad/s, user acceleration in g.
public struct MotionSample: Sendable, Codable, Equatable {
    public var t: TimeInterval
    public var rotationRate: SIMD3<Double>
    public var userAccel: SIMD3<Double>

    public init(t: TimeInterval, rotationRate: SIMD3<Double>, userAccel: SIMD3<Double>) {
        self.t = t
        self.rotationRate = rotationRate
        self.userAccel = userAccel
    }
}
