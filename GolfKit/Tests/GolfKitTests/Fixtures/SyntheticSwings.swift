import Foundation
@testable import GolfKit

/// Deterministic PRNG so synthetic data is reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Additive signal timeline on a fixed sample grid.
struct SyntheticTimeline {
    let rate: Double
    private(set) var rotation: [SIMD3<Double>]
    private(set) var accel: [SIMD3<Double>]

    init(duration: Double, rate: Double = 100) {
        self.rate = rate
        let n = Int((duration * rate).rounded())
        rotation = Array(repeating: .zero, count: n)
        accel = rotation
    }

    private func indices(_ start: Double, _ duration: Double) -> ClosedRange<Int>? {
        let lo = max(0, Int((start * rate - 1e-9).rounded(.up)))
        let hi = min(rotation.count - 1, Int((((start + duration) * rate) + 1e-9).rounded(.down)))
        return lo <= hi ? lo...hi : nil
    }

    /// `f` receives time since `start`.
    mutating func addRotation(start: Double, duration: Double, _ f: (Double) -> SIMD3<Double>) {
        guard let r = indices(start, duration) else { return }
        for i in r { rotation[i] += f(Double(i) / rate - start) }
    }

    mutating func addAccel(start: Double, duration: Double, _ f: (Double) -> SIMD3<Double>) {
        guard let r = indices(start, duration) else { return }
        for i in r { accel[i] += f(Double(i) / rate - start) }
    }

    static let swingAxis: SIMD3<Double> = {
        let v = SIMD3<Double>(0.8, 0.5, 0.33)
        return v / (v * v).sum().squareRoot()
    }()

    /// Full swing whose downswing rotation peaks at `peak` (should be on the sample grid).
    mutating func addSwing(peak: Double, peakRotation: Double = 20, peakAccel: Double = 4, backswingPeak: Double = 5) {
        let d = Self.swingAxis
        // Backswing: 0.9s, sqrt(sin) profile, peak ~backswingPeak rad/s.
        addRotation(start: peak - 1.25, duration: 0.9) { dt in
            d * (backswingPeak * max(0, sin(Double.pi * dt / 0.9)).squareRoot())
        }
        addAccel(start: peak - 1.25, duration: 0.9) { dt in
            SIMD3(0, 0, 0.3 * sin(Double.pi * dt / 0.9))
        }
        // Downswing: 0.3s accelerating to the peak.
        addRotation(start: peak - 0.3, duration: 0.3) { dt in
            d * (-peakRotation * pow(dt / 0.3, 1.5))
        }
        addAccel(start: peak - 0.3, duration: 0.3) { dt in
            SIMD3(0, 0, 0.5 * (dt / 0.3) * (dt / 0.3))
        }
        // Follow-through decay.
        addRotation(start: peak + 0.01, duration: 0.6) { dt in
            d * (-0.7 * peakRotation * exp(-dt / 0.12))
        }
        // Impact spike just after the peak.
        addAccel(start: peak - 0.04, duration: 0.1) { dt in
            let x = (dt - 0.05) / 0.012
            return SIMD3(peakAccel * exp(-x * x), 0, 0)
        }
    }

    /// Sharp rotation + accel spike with no preceding backswing.
    mutating func addFlick(peak: Double, peakRotation: Double = 16, peakAccel: Double = 4) {
        let d = Self.swingAxis
        addRotation(start: peak - 0.1, duration: 0.1) { dt in d * (peakRotation * pow(dt / 0.1, 1.5)) }
        addRotation(start: peak + 0.01, duration: 0.4) { dt in d * (0.7 * peakRotation * exp(-dt / 0.08)) }
        addAccel(start: peak - 0.04, duration: 0.1) { dt in
            let x = (dt - 0.05) / 0.012
            return SIMD3(peakAccel * exp(-x * x), 0, 0)
        }
    }

    /// Render to samples with small deterministic noise.
    func samples(seed: UInt64, rotationNoise: Double = 0.15, accelNoise: Double = 0.03) -> [MotionSample] {
        var rng = SplitMix64(seed: seed)
        return (0..<rotation.count).map { i in
            func n(_ amp: Double) -> SIMD3<Double> {
                SIMD3(Double.random(in: -amp...amp, using: &rng),
                      Double.random(in: -amp...amp, using: &rng),
                      Double.random(in: -amp...amp, using: &rng))
            }
            return MotionSample(t: Double(i) / rate, rotationRate: rotation[i] + n(rotationNoise), userAccel: accel[i] + n(accelNoise))
        }
    }
}

enum SyntheticSwings {
    static let defaultSeed: UInt64 = 42

    /// One full swing; downswing rotation peak at t = 3.0s.
    static func fullSwing(peakRotation: Double = 20, peakAccel: Double = 4, seed: UInt64 = defaultSeed) -> [MotionSample] {
        var tl = SyntheticTimeline(duration: 6)
        tl.addSwing(peak: 3.0, peakRotation: peakRotation, peakAccel: peakAccel)
        return tl.samples(seed: seed)
    }

    /// Two swings whose rotation peaks are `interval` seconds apart (first at 3.0s).
    static func twoSwings(interval: Double, seed: UInt64 = defaultSeed) -> [MotionSample] {
        var tl = SyntheticTimeline(duration: 3 + interval + 3)
        tl.addSwing(peak: 3.0)
        tl.addSwing(peak: 3.0 + (interval * 100).rounded() / 100)
        return tl.samples(seed: seed)
    }

    /// Periodic ~1.5 rad/s rotation and ~0.3 g acceleration, 12s.
    static func walking(seed: UInt64 = defaultSeed) -> [MotionSample] {
        var tl = SyntheticTimeline(duration: 12)
        let d = SyntheticTimeline.swingAxis
        tl.addRotation(start: 0, duration: 12) { dt in d * (1.5 * sin(2 * .pi * 1.8 * dt)) }
        tl.addAccel(start: 0, duration: 12) { dt in SIMD3(0, 0, 0.3 * sin(2 * .pi * 1.8 * dt)) }
        return tl.samples(seed: seed)
    }

    /// Waving: rotation up to ~8 rad/s, no impact spike, 10s.
    static func waving(seed: UInt64 = defaultSeed) -> [MotionSample] {
        var tl = SyntheticTimeline(duration: 10)
        let d = SyntheticTimeline.swingAxis
        tl.addRotation(start: 0, duration: 10) { dt in d * (8 * sin(2 * .pi * 1.2 * dt)) }
        tl.addAccel(start: 0, duration: 10) { dt in SIMD3(0, 0, 0.8 * sin(2 * .pi * 1.2 * dt)) }
        return tl.samples(seed: seed)
    }

    /// Sharp rotation peak (>12) and accel spike with no backswing; peak at t = 3.0s.
    static func flick(seed: UInt64 = defaultSeed) -> [MotionSample] {
        var tl = SyntheticTimeline(duration: 6)
        tl.addFlick(peak: 3.0)
        return tl.samples(seed: seed)
    }

    /// Pure sensor noise.
    static func noise(duration: Double = 10, seed: UInt64 = defaultSeed) -> [MotionSample] {
        SyntheticTimeline(duration: duration).samples(seed: seed, rotationNoise: 0.4, accelNoise: 0.08)
    }
}
