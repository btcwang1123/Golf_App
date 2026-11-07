import Foundation

/// Streaming swing detector. Feed samples in time order; each `ingest` is O(1) amortized
/// (fixed-size ring buffer plus incremental run tracking). Not thread-safe.
public final class SwingDetector {
    public var config: SwingDetectorConfig {
        didSet { reset(); ring = Ring(capacity: Self.capacity(for: config)) }
    }

    private struct Ring {
        let capacity: Int
        var t: [Double], rot: [Double], acc: [Double]
        var head = 0, count = 0
        init(capacity: Int) {
            self.capacity = capacity
            t = Array(repeating: 0, count: capacity)
            rot = t
            acc = t
        }
        mutating func push(_ time: Double, _ r: Double, _ a: Double) {
            t[head] = time; rot[head] = r; acc[head] = a
            head = (head + 1) % capacity
            count = min(count + 1, capacity)
        }
        /// Max accel among samples with time in [lo, hi]; scans only the recent window.
        func maxAccel(from lo: Double, to hi: Double) -> Double {
            var best = 0.0
            for k in 0..<count {
                let i = (head - 1 - k + capacity) % capacity
                if t[i] < lo { break }
                if t[i] <= hi { best = max(best, acc[i]) }
            }
            return best
        }
    }

    private struct Candidate {
        var t: Double
        var rotation: Double
        var downswingStart: Double
        var backswing: (start: Double, end: Double)?
    }

    private var ring: Ring
    private var runStart: Double?
    private var lastAbove: Double = 0
    private var backswingRun: (start: Double, end: Double)?
    private var candidate: Candidate?
    private var armed = true
    private var lastEventT: Double?

    internal var bufferCapacity: Int { ring.capacity }

    private static func capacity(for c: SwingDetectorConfig) -> Int {
        Int(((c.backswingWindow.upperBound + c.impactWindow) * c.sampleRate).rounded(.up)) + 32
    }

    public init(config: SwingDetectorConfig = .default) {
        self.config = config
        self.ring = Ring(capacity: Self.capacity(for: config))
    }

    public func reset() {
        ring.head = 0
        ring.count = 0
        runStart = nil
        backswingRun = nil
        candidate = nil
        armed = true
        lastEventT = nil
    }

    public func ingest(_ s: MotionSample) -> SwingEvent? {
        let t = s.t
        let r = (s.rotationRate * s.rotationRate).sum().squareRoot()
        let a = (s.userAccel * s.userAccel).sum().squareRoot()
        ring.push(t, r, a)

        let minRot = config.effectiveBackswingMinRotation
        let peakThr = config.effectivePeakRotation

        // Track contiguous runs of sustained rotation.
        if r >= minRot {
            if runStart == nil { runStart = t }
            lastAbove = t
        } else if let start = runStart {
            if lastAbove - start >= config.backswingWindow.lowerBound {
                backswingRun = (start, lastAbove)
            }
            runStart = nil
        }

        // Track the local maximum of the current above-threshold segment.
        if r < peakThr {
            armed = true
        } else if armed, let start = runStart, candidate == nil || r > (candidate?.rotation ?? 0) {
            candidate = Candidate(t: t, rotation: r, downswingStart: start, backswing: backswingRun)
        }

        // Decide once the impact window after the peak has elapsed.
        guard let c = candidate, t >= c.t + config.impactWindow - 1e-6 else { return nil }
        candidate = nil
        armed = false
        return evaluate(c, now: t)
    }

    private func evaluate(_ c: Candidate, now: Double) -> SwingEvent? {
        if let last = lastEventT, c.t - last < config.refractory { return nil }
        guard let bs = c.backswing else { return nil }
        let bsDur = bs.end - bs.start
        guard config.backswingWindow.contains(bsDur) else { return nil }
        let gap = c.downswingStart - bs.end
        guard gap >= 0, gap <= config.transitionMax else { return nil }
        let downDur = c.t - c.downswingStart
        guard downDur <= config.downswingMax else { return nil }

        let w = config.impactWindow
        let accel = ring.maxAccel(from: c.t - w - 1e-6, to: c.t + w + 1e-6)
        guard accel >= config.effectiveImpactAccel else { return nil }

        lastEventT = c.t
        let tempo = bsDur / max(downDur, 1 / config.sampleRate)
        return SwingEvent(t: c.t, metrics: SwingMetrics(peakRotation: c.rotation, peakAccel: accel, tempo: tempo))
    }
}
