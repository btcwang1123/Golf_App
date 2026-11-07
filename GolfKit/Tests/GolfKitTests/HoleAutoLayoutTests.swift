import Testing
import Foundation
@testable import GolfKit

struct HoleAutoLayoutTests {
    let origin = GeoPoint(lat: 23.0, lon: 120.3)

    func p(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: origin) }

    /// Fairway corridor from y=a to y=b, 40 m wide.
    func fairway(_ a: Double, _ b: Double, x: Double = 0) -> Polygon {
        [p(x - 20, a), p(x + 20, a), p(x + 20, b), p(x - 20, b)]
    }

    @Test func teeAtFarEndOfAdjoiningFairway() throws {
        let green = p(0, 380)
        let tee = try #require(HoleAutoLayout.estimateTee(green: green, fairways: [fairway(0, 350)]))
        #expect(Geo.distance(tee, green) > 370 && Geo.distance(tee, green) < 390)
        #expect(tee.lat < green.lat)
    }

    @Test func picksNearestFairwayAndIgnoresDistantOnes() throws {
        let green = p(0, 300)
        let other = fairway(0, 400, x: 200)  // parallel hole 200 m away
        let tee = try #require(HoleAutoLayout.estimateTee(green: green, fairways: [other, fairway(20, 280)]))
        #expect(abs(Geo.project(tee, origin: origin).x) < 25)
    }

    @Test func noFairwayNearbyReturnsNil() {
        #expect(HoleAutoLayout.estimateTee(green: p(0, 300), fairways: [fairway(0, 200, x: 300)]) == nil)
        #expect(HoleAutoLayout.estimateTee(green: p(0, 0), fairways: []) == nil)
    }

    @Test func tooShortReturnsNil() {
        #expect(HoleAutoLayout.estimateTee(green: p(0, 60), fairways: [fairway(0, 50)]) == nil)
    }

    @Test func capsMergedFairways() throws {
        let green = p(0, 0)
        let tee = try #require(HoleAutoLayout.estimateTee(green: green, fairways: [fairway(-900, 10)]))
        #expect(Geo.distance(tee, green) <= HoleAutoLayout.maxHoleMeters)
    }

    @Test func parFromLength() {
        #expect(HoleAutoLayout.guessPar(lengthMeters: 150) == 3)
        #expect(HoleAutoLayout.guessPar(lengthMeters: 350) == 4)
        #expect(HoleAutoLayout.guessPar(lengthMeters: 470) == 5)
    }

    @Test func aerialSetAppendsWithoutDuplicates() {
        let f = Feature(kind: .bunker, polygon: [p(0, 0), p(5, 0), p(5, 5)])
        let course = Course(id: "osm-way-1", name: "A", center: origin, features: [f])
        let set = AerialFeatureSet(attribution: "x", courses: ["osm-way-1": [f, Feature(kind: .water, polygon: f.polygon)]])
        let out = set.apply(to: [course, Course(id: "osm-way-2", name: "B", center: origin)])
        #expect(out[0].features.count == 2)
        #expect(out[1].features.isEmpty)
    }
}
