import Foundation

/// Thresholds for `SwingDetector`. Rotation in rad/s, acceleration in g, times in seconds.
public struct SwingDetectorConfig: Sendable, Codable, Equatable {
    /// Downswing rotation-magnitude peak required (rad/s).
    public var peakRotation: Double = 12
    /// Sustained rotation magnitude that counts as backswing (rad/s).
    public var backswingMinRotation: Double = 3
    /// Allowed backswing duration range (s).
    public var backswingWindow: ClosedRange<Double> = 0.4...2.5
    /// Acceleration magnitude required at impact (g).
    public var impactAccel: Double = 2.5
    /// Impact must occur within ± this many seconds of the rotation peak.
    public var impactWindow: Double = 0.12
    /// Minimum seconds between two emitted events.
    public var refractory: Double = 4
    /// Scales thresholds: effective = base / sensitivity (clamped to 0.5...1.5).
    public var sensitivity: Double = 1
    /// Expected sample rate, used only to size the ring buffer.
    public var sampleRate: Double = 100
    /// Max pause between backswing end and downswing start (s).
    public var transitionMax: Double = 0.5
    /// Max downswing duration (downswing start to peak) (s).
    public var downswingMax: Double = 0.6

    public static let sensitivityRange: ClosedRange<Double> = 0.5...1.5

    public static let `default` = SwingDetectorConfig()

    public init() {}

    public var effectiveSensitivity: Double {
        min(max(sensitivity, Self.sensitivityRange.lowerBound), Self.sensitivityRange.upperBound)
    }
    public var effectivePeakRotation: Double { peakRotation / effectiveSensitivity }
    public var effectiveBackswingMinRotation: Double { backswingMinRotation / effectiveSensitivity }
    public var effectiveImpactAccel: Double { impactAccel / effectiveSensitivity }
}
