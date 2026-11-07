import Testing
import Foundation
@testable import GolfKit

struct GeometryTests {
    let origin = GeoPoint(lat: 25.0, lon: 121.0)

    func offset(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: origin) }

    @Test func distanceKnown() {
        // Taipei 101 -> Taipei Main Station, ~4.5 km via known 1 degree lat = 111.195 km
        let d = Geo.distance(GeoPoint(lat: 25, lon: 121), GeoPoint(lat: 26, lon: 121))
        #expect(abs(d - 111_195) / 111_195 < 0.005)
        let e = Geo.distance(GeoPoint(lat: 0, lon: 0), GeoPoint(lat: 0, lon: 1))
        #expect(abs(e - 111_195) / 111_195 < 0.005)
    }

    @Test func bearingAndMidpoint() {
        #expect(abs(Geo.bearing(origin, GeoPoint(lat: 26, lon: 121))) < 0.01)
        #expect(abs(Geo.bearing(GeoPoint(lat: 0, lon: 0), GeoPoint(lat: 0, lon: 1)) - 90) < 0.01)
        let m = Geo.midpoint(GeoPoint(lat: 0, lon: 0), GeoPoint(lat: 0, lon: 2))
        #expect(abs(m.lon - 1) < 1e-9 && abs(m.lat) < 1e-9)
    }

    @Test func concaveContains() {
        // U shape opening upward
        let u: Polygon = [(0, 0), (30, 0), (30, 30), (20, 30), (20, 10), (10, 10), (10, 30), (0, 30)].map { offset($0.0, $0.1) }
        #expect(PolygonOps.contains(offset(5, 15), in: u))
        #expect(PolygonOps.contains(offset(25, 15), in: u))
        #expect(PolygonOps.contains(offset(15, 5), in: u))
        #expect(!PolygonOps.contains(offset(15, 20), in: u))
        #expect(!PolygonOps.contains(offset(40, 5), in: u))
    }

    @Test func centroidAndPolylineDistance() throws {
        let sq: Polygon = [(0, 0), (20, 0), (20, 10), (0, 10)].map { offset($0.0, $0.1) }
        let c = try #require(PolygonOps.centroid(sq))
        #expect(Geo.distance(c, offset(10, 5)) < 0.1)
        let line = [offset(0, 0), offset(100, 0)]
        #expect(abs(PolygonOps.distance(from: offset(50, 7), toPolyline: line) - 7) < 0.1)
        #expect(abs(PolygonOps.distance(from: offset(130, 0), toPolyline: line) - 30) < 0.1)
    }

    @Test func simplifyKeepsEndsAndReduces() {
        let pts = (0...20).map { offset(Double($0) * 5, $0 % 2 == 0 ? 0 : 0.5) }
        let s = Simplify.douglasPeucker(pts, epsilonMeters: 2)
        #expect(s.count < pts.count)
        #expect(s.first == pts.first && s.last == pts.last)
        let bend = [offset(0, 0), offset(50, 0), offset(50, 50)]
        #expect(Simplify.douglasPeucker(bend, epsilonMeters: 2).count == 3)
    }

    @Test func greenPolygonFrontCenterBack() throws {
        let green: Polygon = [(-10, 90), (10, 90), (10, 110), (-10, 110)].map { offset($0.0, $0.1) }
        let hole = Hole(number: 1, greenCenter: offset(0, 100), green: green)
        let d = try #require(hole.greenDistancesMeters(from: origin))
        #expect(abs(d.front - 90) < 0.5)
        #expect(abs(d.center - 100) < 0.5)
        #expect(abs(d.back - 110) < 0.5)
    }

    @Test func greenWithoutPolygonUsesTwelveMeters() throws {
        let hole = Hole(number: 1, greenCenter: offset(0, 100))
        let d = try #require(hole.greenDistancesMeters(from: origin))
        #expect(abs(d.front - 88) < 0.5)
        #expect(abs(d.back - 112) < 0.5)
        #expect(Hole(number: 2).greenFrontCenterBack(from: origin) == nil)
    }
}
