import Testing
import Foundation
@testable import GolfKit

struct HoleTargetsTests {
    @Test func defaultTargetAhead() throws {
        let h = V2.fullHole()
        let t = try #require(h.defaultTarget(from: nil, carry: 200))
        #expect(Geo.distance(t, V2.at(0, 200)) < 0.5)
        let mid = try #require(h.defaultTarget(from: V2.at(5, 100), carry: 150))
        #expect(Geo.distance(mid, V2.at(0, 250)) < 0.5)
        #expect(h.defaultTarget(from: V2.at(0, 300), carry: 200) == nil)
    }

    @Test func pinPresetsInsideGreen() throws {
        let h = V2.fullHole()
        let p = try #require(h.pinPresets())
        for q in [p.front, p.center, p.back] { #expect(PolygonOps.contains(q, in: try #require(h.green))) }
        #expect(Geo.project(p.front, origin: V2.origin).y < Geo.project(p.back, origin: V2.origin).y)
    }

    @Test func pinReplacesCenterDistance() throws {
        let h = V2.fullHole()
        let d = try #require(h.distancesMeters(from: V2.origin, pin: V2.at(0, 390)))
        #expect(abs(d.center - 390) < 0.5)
        #expect(abs(d.front - 365) < 0.5)
    }
}
