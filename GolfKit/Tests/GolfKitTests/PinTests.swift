import Testing
import Foundation
@testable import GolfKit

struct PinTests {
    let rid = UUID()

    @Test func pinStoredAndUsedForLastShot() throws {
        let course = V2.course(holes: 1)
        let pin = V2.at(0, 390)
        let events = [
            V2.ev(rid, 0, .setPin(hole: 1, location: V2.at(0, 370))),
            V2.ev(rid, 1, .setPin(hole: 1, location: pin)),
            V2.ev(rid, 2, .stroke(hole: 1, type: .swing, location: V2.at(0, 300), swing: nil)),
        ]
        let s = RoundReducer.reduce(events, course: course)
        #expect(s.pin(for: 1) == pin)
        #expect(abs(try #require(s.hole(1)?.shots.first?.distanceToNext) - 90) < 1)
    }

    @Test func clampIntoGreen() {
        let green = V2.rect(-10, -10, 10, 10)
        let inside = V2.at(3, 3)
        #expect(PolygonOps.clamp(inside, into: green) == inside)
        let snapped = PolygonOps.clamp(V2.at(25, 0), into: green)
        #expect(abs(Geo.project(snapped, origin: V2.origin).x - 10) < 0.05)
        #expect(abs(Geo.project(snapped, origin: V2.origin).y) < 0.05)
    }
}
