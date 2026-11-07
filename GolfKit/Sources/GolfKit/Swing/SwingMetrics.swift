import Foundation

/// Summary of a detected swing.
public struct SwingMetrics: Sendable, Codable, Equatable, Hashable {
    /// Peak gyroscope magnitude during the downswing (rad/s).
    public var peakRotation: Double
    /// Peak user-acceleration magnitude around impact (g).
    public var peakAccel: Double
    /// Backswing duration ÷ downswing duration.
    public var tempo: Double

    public init(peakRotation: Double, peakAccel: Double, tempo: Double) {
        self.peakRotation = peakRotation
        self.peakAccel = peakAccel
        self.tempo = tempo
    }
}
