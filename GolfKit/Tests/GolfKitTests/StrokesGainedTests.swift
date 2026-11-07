import Testing
import Foundation
@testable import GolfKit

struct StrokesGainedTests {
    let rid = UUID()

    @Test func baselineMonotonic() {
        #expect(BaselineTable.expected(distance: 1, lie: .green) < BaselineTable.expected(distance: 10, lie: .green))
        #expect(BaselineTable.expected(distance: 150, lie: .fairway) < BaselineTable.expected(distance: 150, lie: .rough))
        #expect(BaselineTable.expected(distance: 600, lie: .fairway) > BaselineTable.expected(distance: 500, lie: .fairway))
        let mid = BaselineTable.expected(distance: 112.5, lie: .fairway)
        #expect(abs(mid - 3.375) < 1e-9)
    }

    @Test func lieClassifier() {
        let h = V2.fullHole()
        #expect(LieClassifier.classify(V2.at(0, 380), hole: h) == .green)
        #expect(LieClassifier.classify(V2.at(20, 230), hole: h) == .sand)
        #expect(LieClassifier.classify(V2.at(0, 200), hole: h) == .fairway)
        #expect(LieClassifier.classify(V2.at(50, 200), hole: h) == .rough)
        #expect(LieClassifier.classify(V2.at(2, 2), hole: h) == .tee)
    }

    @Test func holeBreakdownSumsToExpectedMinusScore() throws {
        let course = V2.course(holes: 1)
        let events = [
            V2.ev(rid, 0, .stroke(hole: 1, type: .swing, location: V2.origin, swing: nil)),
            V2.ev(rid, 1, .stroke(hole: 1, type: .swing, location: V2.at(0, 230), swing: nil)),
            V2.ev(rid, 2, .stroke(hole: 1, type: .swing, location: V2.at(0, 355), swing: nil)),
            V2.ev(rid, 3, .stroke(hole: 1, type: .putt, location: V2.at(0, 375), swing: nil)),
            V2.ev(rid, 4, .stroke(hole: 1, type: .putt, location: V2.at(0, 379), swing: nil)),
        ]
        let s = RoundReducer.reduce(events, course: course)
        let sg = StrokesGained.compute(state: s, course: course)
        #expect(sg.holesCounted == 1)
        let expected = BaselineTable.expected(distance: 380, lie: .tee) - 5
        #expect(abs(sg.total - expected) < 1e-6)
        #expect(sg.offTee != 0 && sg.putting != 0 && sg.shortGame != 0 && sg.approach != 0)
    }

    @Test func excludesIncompleteHolesAndHandlesMissingPuttGPS() {
        var course = V2.course(holes: 2)
        course.holes[1].green = nil
        let events = [
            V2.ev(rid, 0, .stroke(hole: 1, type: .swing, location: V2.origin, swing: nil)),
            V2.ev(rid, 1, .stroke(hole: 1, type: .swing, location: V2.at(0, 360), swing: nil)),
            V2.ev(rid, 2, .stroke(hole: 1, type: .putt, location: nil, swing: nil)),
            V2.ev(rid, 3, .stroke(hole: 1, type: .putt, location: nil, swing: nil)),
            V2.ev(rid, 4, .stroke(hole: 2, type: .swing, location: V2.origin, swing: nil)),
        ]
        let sg = StrokesGained.compute(state: RoundReducer.reduce(events, course: course), course: course)
        #expect(sg.holesCounted == 1)
        #expect(sg.holesExcluded == 1)
        #expect(abs(sg.putting - (BaselineTable.defaultPuttExpectation - 2)) < 1e-9)
    }
}
