import Foundation

public enum WindComponent {
    /// Head (+) / tail (−) and cross (+ = blowing left→right) components in the wind's speed unit.
    /// - Parameters:
    ///   - windFromDeg: meteorological direction the wind comes FROM (0 = north).
    ///   - holeBearing: direction of play (tee → green).
    public static func relative(windFromDeg: Double, speed: Double, holeBearing: Double) -> (head: Double, cross: Double) {
        let d = (holeBearing - windFromDeg) * .pi / 180
        return (speed * cos(d), speed * sin(d))
    }

    /// Arrow rotation (degrees, 0 = straight up the hole) showing where the wind blows TO.
    public static func arrowRotation(windFromDeg: Double, holeBearing: Double) -> Double {
        let to = windFromDeg + 180
        return ((to - holeBearing).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Below this (m/s) a component is not mentioned.
    public static let calmThreshold = 1.0

    /// e.g. "逆風 4 m/s · 左往右側風"; "無風" when calm.
    public static func describe(head: Double, cross: Double) -> String {
        var parts: [String] = []
        if abs(head) >= calmThreshold {
            parts.append("\(head > 0 ? "逆風" : "順風") \(Int(abs(head).rounded())) m/s")
        }
        if abs(cross) >= calmThreshold {
            parts.append(cross > 0 ? "左往右側風" : "右往左側風")
        }
        return parts.isEmpty ? "無風" : parts.joined(separator: " · ")
    }
}
