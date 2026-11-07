import Testing
import Foundation
@testable import GolfKit

struct PointAveragerTests {
    @Test func rejectsInaccurateSamples() {
        var a = PointAverager()
        a.add(V2.at(0, 0), accuracy: 15)
        a.add(V2.at(0, 0), accuracy: -1)
        #expect(a.result == nil)
        #expect(a.rejected == 2)
    }

    @Test func averagesAndSpread() throws {
        var a = PointAverager()
        for (x, y) in [(2.0, 0.0), (-2.0, 0.0), (0.0, 2.0), (0.0, -2.0)] { a.add(V2.at(x, y), accuracy: 5) }
        let r = try #require(a.result)
        #expect(Geo.distance(r, V2.origin) < 0.01)
        #expect(abs(a.spreadMeters - 2) < 0.01)
        #expect(a.meanAccuracy == 5)
        #expect(!a.needsRetry)
    }

    @Test func warnsWhenImprecise() {
        var a = PointAverager()
        a.add(V2.at(0, 0), accuracy: 9)
        a.add(V2.at(0, 1), accuracy: 9.5)
        #expect(a.needsRetry)
    }

    @Test func trackClosesIntoPolygon() throws {
        var track: [GeoPoint] = []
        for i in 0..<72 {
            let a = Double(i) / 72 * 2 * .pi
            track.append(V2.at(15 * cos(a), 15 * sin(a)))
        }
        let poly = try #require(TrackPolygon.close(track))
        #expect(poly.count >= 3 && poly.count < track.count)
        #expect(PolygonOps.contains(V2.origin, in: poly))
        #expect(TrackPolygon.close([V2.origin, V2.at(1, 0)]) == nil)
    }
}
