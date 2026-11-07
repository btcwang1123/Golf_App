import Foundation

/// A detected swing. `t` is the timestamp of the downswing rotation peak.
public struct SwingEvent: Sendable, Codable, Equatable {
    public var t: TimeInterval
    public var metrics: SwingMetrics

    public init(t: TimeInterval, metrics: SwingMetrics) {
        self.t = t
        self.metrics = metrics
    }
}
