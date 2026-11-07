import Testing
import Foundation
@testable import GolfKit

struct DispersionStatsTests {
    let rid = UUID()

    @Test func lateralSign() {
        let target = V2.at(0, 200)
        #expect(abs(DispersionStats.lateral(shot: V2.origin, next: V2.at(10, 150), target: target) - 10) < 0.01)
        #expect(abs(DispersionStats.lateral(shot: V2.origin, next: V2.at(-8, 150), target: target) + 8) < 0.01)
    }

    @Test func profileExcludesOutliersPuttsAndPenalized() throws {
        let course = V2.course(holes: 1)
        var events: [RoundEvent] = []
        var t = 0.0
        func add(_ k: RoundEvent.Kind, id: UUID = UUID()) { events.append(V2.ev(rid, t, k, id: id)); t += 1 }
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        add(.stroke(hole: 1, type: .swing, location: V2.at(0, 0), swing: nil), id: a)       // 200 m
        add(.stroke(hole: 1, type: .swing, location: V2.at(0, 200), swing: nil), id: b)     // 5 m (outlier)
        add(.stroke(hole: 1, type: .swing, location: V2.at(0, 205), swing: nil), id: c)     // 150 m, penalized
        add(.penalty(hole: 1, count: 1))
        add(.stroke(hole: 1, type: .swing, location: V2.at(0, 355), swing: nil), id: d)
        add(.stroke(hole: 1, type: .putt, location: V2.at(0, 375), swing: nil))
        for (id, club) in [(a, Club.driver), (b, .lw), (c, .i7), (d, .pw)] { add(.setClub(strokeId: id, club: club)) }
        let s = RoundReducer.reduce(events, course: course)
        #expect(s.hole(1)?.penalizedShotIds == [c])
        let p = ClubProfile.build(rounds: [s], courses: ["c": course])
        #expect(abs(try #require(p[.driver]).median - 200) < 1)
        #expect(p[.lw] == nil)
        #expect(p[.i7] == nil)
        #expect(p[.pw]?.count == 1)
        #expect(p[.driver]?.dispersion.count == 1)
        #expect(ClubProfile.percentile([1, 2, 3, 4], 0.5) == 2.5)
        #expect(p.driveDistance == ClubProfile.defaultDrive)
    }
}
