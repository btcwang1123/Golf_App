import Foundation

/// Expected strokes to hole out for a ~15 handicap amateur. Hand-built smooth curves
/// based on common knowledge; tune here. Distances in meters.
public enum BaselineTable {
    public static let green: [(Double, Double)] = [
        (0.3, 1.0), (1, 1.1), (2, 1.35), (3, 1.55), (5, 1.8), (8, 1.98), (12, 2.12), (18, 2.28), (25, 2.42), (40, 2.65),
    ]
    public static let fairway: [(Double, Double)] = [
        (5, 2.45), (15, 2.65), (30, 2.85), (50, 3.0), (75, 3.15), (100, 3.3), (125, 3.45), (150, 3.62),
        (175, 3.82), (200, 4.02), (250, 4.38), (300, 4.72), (400, 5.25), (500, 5.75),
    ]
    public static let rough: [(Double, Double)] = fairway.map { ($0.0, $0.1 + ($0.0 < 30 ? 0.12 : 0.22)) }
    public static let sand: [(Double, Double)] = [
        (5, 2.75), (15, 2.95), (30, 3.2), (50, 3.4), (100, 3.75), (150, 4.05), (200, 4.4),
    ]
    public static let tee: [(Double, Double)] = [
        (90, 3.05), (130, 3.3), (170, 3.55), (210, 3.85), (260, 4.1), (300, 4.3), (340, 4.5),
        (380, 4.72), (430, 4.98), (480, 5.25), (530, 5.55),
    ]
    public static let recovery: [(Double, Double)] = fairway.map { ($0.0, $0.1 + 0.6) }

    /// Used when the first putt has no GPS fix.
    public static let defaultPuttExpectation = 1.95

    public static func expected(distance: Double, lie: Lie) -> Double {
        let table: [(Double, Double)]
        switch lie {
        case .green: table = green
        case .fairway: table = fairway
        case .rough: table = rough
        case .sand: table = sand
        case .tee: table = tee
        case .recovery: table = recovery
        }
        return interpolate(table, max(0, distance))
    }

    static func interpolate(_ t: [(Double, Double)], _ x: Double) -> Double {
        guard let first = t.first, let last = t.last else { return 0 }
        if x <= first.0 { return first.1 }
        if x >= last.0 {
            // Extend with the last slope.
            let prev = t[t.count - 2]
            return last.1 + (x - last.0) * (last.1 - prev.1) / (last.0 - prev.0)
        }
        for (a, b) in zip(t, t.dropFirst()) where x <= b.0 {
            return a.1 + (x - a.0) / (b.0 - a.0) * (b.1 - a.1)
        }
        return last.1
    }
}
