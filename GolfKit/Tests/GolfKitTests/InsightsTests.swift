import Testing
import Foundation
@testable import GolfKit

struct InsightsTests {
    func round(holes: Int, strokesPerHole: Int, day: Double, manual: Bool = true) -> RoundState {
        let rid = UUID()
        var events = [V2.ev(rid, day * 86400, .start(courseId: "c"))]
        var t = day * 86400 + 1
        for h in 1...holes {
            events.append(V2.ev(rid, t, .setPar(hole: h, par: 4))); t += 1
            for i in 0..<strokesPerHole {
                let type: RoundEvent.StrokeType = i >= strokesPerHole - 2 ? .putt : (manual ? .manual : .swing)
                events.append(V2.ev(rid, t, .stroke(hole: h, type: type, location: manual ? nil : V2.at(0, Double(i) * 10), swing: nil))); t += 1
            }
        }
        return RoundReducer.reduce(events, course: nil)
    }

    @Test func nineAndEighteenSeparate() throws {
        let rounds = [round(holes: 18, strokesPerHole: 5, day: 1), round(holes: 9, strokesPerHole: 4, day: 2),
                      round(holes: 18, strokesPerHole: 4, day: 3)]
        let s = InsightsSummary.make(rounds: rounds, courses: [:], lastN: nil)
        #expect(s.roundCount == 3)
        #expect(s.averageScore18 == 81)
        #expect(s.averageScore9 == 36)
        #expect(s.best18 == 72)
        #expect(abs(try #require(s.averageToPar) - 18 * 18.0 / 45) < 1e-9)
        #expect(s.trend.first?.strokes == 90)
        #expect(s.trend.last?.strokes == 72)
        #expect(s.breakdown.share(.par) > 0.5)
        #expect(s.parTypeAverage[4] != nil)
        #expect(s.firPercent == nil) // manual rounds don't count for FIR
        #expect(s.hasEnoughData)
    }

    @Test func lastNAndEmpty() {
        let rounds = (1...6).map { round(holes: 18, strokesPerHole: 4 + $0 % 2, day: Double($0)) }
        #expect(InsightsSummary.make(rounds: rounds, courses: [:], lastN: 5).roundCount == 5)
        #expect(!InsightsSummary.make(rounds: Array(rounds.prefix(2)), courses: [:], lastN: nil).hasEnoughData)
        #expect(InsightsSummary.movingAverage([1, 2, 3, 4], window: 2) == [1, 1.5, 2.5, 3.5])
    }
}
