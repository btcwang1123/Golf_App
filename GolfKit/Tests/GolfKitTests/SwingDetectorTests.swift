import Testing
import Foundation
@testable import GolfKit

@Suite("SwingDetector")
struct SwingDetectorTests {
    private func run(_ samples: [MotionSample], config: SwingDetectorConfig = .default) -> [SwingEvent] {
        let d = SwingDetector(config: config)
        return samples.compactMap { d.ingest($0) }
    }

    @Test func fullSwingDetectedOnce() {
        let events = run(SyntheticSwings.fullSwing())
        #expect(events.count == 1)
        guard let e = events.first else { return }
        #expect(abs(e.t - 3.0) < 0.011)
        #expect(e.metrics.peakRotation > 19 && e.metrics.peakRotation < 21)
        #expect(e.metrics.peakAccel > 3.5 && e.metrics.peakAccel < 4.5)
        #expect(e.metrics.tempo > 2 && e.metrics.tempo < 8)
    }

    @Test func fullSwingAcrossSeeds() {
        for seed in UInt64(1)...20 {
            #expect(run(SyntheticSwings.fullSwing(seed: seed)).count == 1)
        }
    }

    @Test func nonSwingsDoNotTrigger() {
        #expect(run(SyntheticSwings.walking()).isEmpty)
        #expect(run(SyntheticSwings.waving()).isEmpty)
        #expect(run(SyntheticSwings.flick()).isEmpty)
        #expect(run(SyntheticSwings.noise()).isEmpty)
    }

    @Test func twoSwingsWithinRefractoryCountOnce() {
        #expect(run(SyntheticSwings.twoSwings(interval: 2.5)).count == 1)
    }

    @Test func twoSwingsBeyondRefractoryCountTwice() {
        let events = run(SyntheticSwings.twoSwings(interval: 6))
        #expect(events.count == 2)
        if events.count == 2 { #expect(abs((events[1].t - events[0].t) - 6) < 0.011) }
    }

    @Test func sensitivityScalesThresholds() {
        var c = SwingDetectorConfig.default
        #expect(c.effectivePeakRotation == 12)
        c.sensitivity = 1.5
        #expect(abs(c.effectivePeakRotation - 8) < 1e-9)
        #expect(abs(c.effectiveImpactAccel - 2.5 / 1.5) < 1e-9)
        #expect(abs(c.effectiveBackswingMinRotation - 2) < 1e-9)
        c.sensitivity = 0.5
        #expect(abs(c.effectivePeakRotation - 24) < 1e-9)
        c.sensitivity = 10 // clamped
        #expect(c.effectiveSensitivity == 1.5)
        c.sensitivity = 0.01
        #expect(c.effectiveSensitivity == 0.5)
    }

    @Test func weakSwingNeedsHighSensitivity() {
        let weak = SyntheticSwings.fullSwing(peakRotation: 10, peakAccel: 2.0)
        var c = SwingDetectorConfig.default
        #expect(run(weak, config: c).isEmpty)
        c.sensitivity = 1.3
        #expect(run(weak, config: c).count == 1)
        // Strong swing is rejected at low sensitivity only when below the raised threshold.
        c.sensitivity = 0.5
        #expect(run(SyntheticSwings.fullSwing(peakRotation: 20, peakAccel: 4), config: c).isEmpty)
    }

    @Test func resetClearsState() {
        let d = SwingDetector()
        let swing = SyntheticSwings.fullSwing()
        #expect(swing.compactMap { d.ingest($0) }.count == 1)
        d.reset()
        #expect(swing.compactMap { d.ingest($0) }.count == 1) // refractory cleared
    }

    @Test func ingestIsConstantSpaceAndFast() {
        let d = SwingDetector()
        let cap = d.bufferCapacity
        var rng = SplitMix64(seed: 7)
        let clock = ContinuousClock()
        var count = 0
        let elapsed = clock.measure {
            for i in 0..<100_000 {
                let s = MotionSample(
                    t: Double(i) / 100,
                    rotationRate: SIMD3(Double.random(in: -1...1, using: &rng), 0, 0),
                    userAccel: SIMD3(0, Double.random(in: -0.1...0.1, using: &rng), 0))
                if d.ingest(s) != nil { count += 1 }
            }
        }
        #expect(count == 0)
        #expect(d.bufferCapacity == cap)
        #expect(cap == Int(((2.5 + 0.12) * 100).rounded(.up)) + 32)
        #expect(elapsed < .seconds(2))
    }

    @Test func configCodableRoundTrip() throws {
        let c = SwingDetectorConfig.default
        let back = try JSONDecoder().decode(SwingDetectorConfig.self, from: JSONEncoder().encode(c))
        #expect(back == c)
    }
}
