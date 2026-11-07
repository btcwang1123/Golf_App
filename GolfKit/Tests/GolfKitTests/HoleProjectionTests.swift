import CoreGraphics
import Testing
import Foundation
@testable import GolfKit

struct HoleProjectionTests {
    @Test func teeBottomGreenTop() throws {
        // Hole playing due east: after rotation the green must be above the tee.
        let hole = Hole(number: 1, tee: V2.origin, greenCenter: V2.at(300, 0))
        let p = try #require(HoleProjection(hole: hole, size: CGSize(width: 200, height: 400)))
        let tee = p.project(V2.origin), green = p.project(V2.at(300, 0))
        #expect(abs(tee.x - green.x) < 0.5)
        #expect(green.y < tee.y)
        #expect(tee.y <= 400 && green.y >= 0)
    }

    @Test func unprojectInverts() throws {
        let hole = V2.fullHole()
        let p = try #require(HoleProjection(hole: hole, size: CGSize(width: 180, height: 220), zoom: 2))
        let q = V2.at(12, 250)
        #expect(Geo.distance(p.unproject(p.project(q)), q) < 0.01)
        #expect(HoleProjection(hole: Hole(number: 1), size: CGSize(width: 10, height: 10)) == nil)
    }
}
