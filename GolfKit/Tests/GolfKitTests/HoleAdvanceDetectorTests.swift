import Testing
import Foundation
@testable import GolfKit

struct HoleAdvanceDetectorTests {
    let origin = GeoPoint(lat: 25.0, lon: 121.0)
    func at(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: origin) }

    // Hole 1: tee (0,0) -> green (0,300). Hole 2 tee at (50,310).
    var course: Course {
        Course(id: "c", name: "C", center: origin, holes: [
            Hole(number: 1, par: 4, tee: at(0, 0), greenCenter: at(0, 300)),
            Hole(number: 2, par: 4, tee: at(50, 310), greenCenter: at(50, 600)),
        ])
    }

    func state(putts: Int) -> HoleState {
        HoleState(number: 1, par: 4, strokes: 3 + putts, putts: putts, total: 3 + putts)
    }

    @Test func noPuttReturnsNil() {
        #expect(HoleAdvanceDetector.suggest(current: 1, location: at(50, 310), state: state(putts: 0), course: course) == nil)
    }

    @Test func nearNextTeeFarFromGreenAdvances() {
        #expect(HoleAdvanceDetector.suggest(current: 1, location: at(50, 320), state: state(putts: 2), course: course) == 2)
    }

    @Test func nearTeeButCloseToGreenReturnsNil() {
        let c = Course(id: "c", name: "C", center: origin, holes: [
            Hole(number: 1, par: 4, tee: at(0, 0), greenCenter: at(0, 300)),
            Hole(number: 2, par: 4, tee: at(0, 320), greenCenter: at(0, 600)),
        ])
        // 20 m from green, 0 m from next tee.
        #expect(HoleAdvanceDetector.suggest(current: 1, location: at(0, 320), state: state(putts: 1), course: c) == nil)
    }

    @Test func farFromNextTeeReturnsNil() {
        #expect(HoleAdvanceDetector.suggest(current: 1, location: at(0, 280), state: state(putts: 1), course: course) == nil)
    }

    @Test func lastHoleReturnsNil() {
        #expect(HoleAdvanceDetector.suggest(current: 2, location: at(50, 320), state: state(putts: 1), course: course) == nil)
    }

    @Test func noMapDataReturnsNil() {
        let c = Course(id: "c", name: "C", center: origin, holes: [Hole(number: 1), Hole(number: 2)])
        #expect(!c.hasHoleMaps)
        #expect(HoleAdvanceDetector.suggest(current: 1, location: at(50, 320), state: state(putts: 1), course: c) == nil)
    }

    @Test func unknownCurrentGreenUsesTeeRuleOnly() {
        let c = Course(id: "c", name: "C", center: origin, holes: [
            Hole(number: 1), Hole(number: 2, tee: at(50, 310)),
        ])
        #expect(HoleAdvanceDetector.suggest(current: 1, location: at(50, 320), state: state(putts: 1), course: c) == 2)
    }

    @Test func customConfigRadius() {
        let d = HoleAdvanceDetector(config: .init(nextTeeRadius: 5, leaveGreenDistance: 30))
        #expect(d.suggest(current: 1, location: at(50, 330), state: state(putts: 1), course: course) == nil)
    }
}
