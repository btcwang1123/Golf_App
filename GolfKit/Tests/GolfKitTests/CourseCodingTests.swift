import Testing
import Foundation
@testable import GolfKit

struct CourseCodingTests {
    func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "sample_course", withExtension: "json", subdirectory: "Data"))
        return try Data(contentsOf: url)
    }

    @Test func roundTrip() throws {
        let first = try Course.decodeList(from: fixture())
        #expect(first.count == 1)
        #expect(first[0].holes.count == 2)
        let again = try Course.decodeList(from: Course.encodeList(first))
        #expect(first == again)
    }

    @Test func missingParAndGreenDecode() throws {
        let c = try Course.decodeList(from: fixture())[0]
        let h2 = try #require(c.hole(2))
        #expect(h2.par == nil)
        #expect(h2.green == nil)
        #expect(h2.greenCenter == nil)
        #expect(h2.features.isEmpty)
        #expect(h2.effectiveGreenCenter == h2.path.last)
        #expect(h2.effectiveTee == h2.path.first)
        #expect(c.hasHoleMaps)
    }

    @Test func minimalHoleJSON() throws {
        let h = try JSONDecoder().decode(Hole.self, from: Data(#"{"number":3}"#.utf8))
        #expect(h == Hole(number: 3))
        #expect(h.lengthMeters == nil)
    }

    @Test func coordinatesRoundedToSixDecimals() throws {
        let data = try JSONEncoder().encode(GeoPoint(lat: 25.12345678912, lon: 121.1))
        let p = try JSONDecoder().decode(GeoPoint.self, from: data)
        #expect(p.lat == 25.123457)
    }

    @Test func clubNamesAndLength() throws {
        #expect(Club.driver.displayName == "1W")
        #expect(Club.allCases.count == 15)
        let c = try Course.decodeList(from: fixture())[0]
        let len = try #require(c.hole(1)?.lengthMeters)
        #expect(abs(len - 333.6) < 2)
    }
}
