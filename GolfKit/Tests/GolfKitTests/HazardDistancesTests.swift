import Testing
import Foundation
@testable import GolfKit

struct HazardDistancesTests {
    func hole(_ features: [Feature]) -> Hole {
        Hole(number: 1, par: 4, tee: V2.origin, greenCenter: V2.at(0, 380), features: features)
    }

    @Test func frontAndCarryOnLine() throws {
        let h = hole([Feature(kind: .bunker, polygon: V2.rect(-10, 200, 10, 230))])
        let r = HazardDistances.compute(from: V2.origin, hole: h)
        let b = try #require(r.first)
        #expect(abs(b.front - 200) < 0.5)
        #expect(abs(b.carry - 230) < 0.5)
        #expect(b.side == .center)
    }

    @Test func sideFilterAndSorting() {
        let h = hole([
            Feature(kind: .water, polygon: V2.rect(20, 250, 40, 280)),   // right, ahead
            Feature(kind: .bunker, polygon: V2.rect(-35, 150, -25, 170)), // left, ahead
            Feature(kind: .bunker, polygon: V2.rect(60, 100, 80, 120)),   // too far right
            Feature(kind: .bunker, polygon: V2.rect(-5, -60, 5, -40)),    // behind
            Feature(kind: .fairway, polygon: V2.rect(-20, 100, 20, 300)), // not a hazard
        ])
        let r = HazardDistances.compute(from: V2.origin, hole: h)
        #expect(r.count == 2)
        #expect(r.map(\.kind) == [.bunker, .water])
        #expect(r[0].side == .left && r[1].side == .right)
        #expect(abs(r[1].front - 250) < 0.5 && abs(r[1].carry - 280) < 0.5)
    }
}
