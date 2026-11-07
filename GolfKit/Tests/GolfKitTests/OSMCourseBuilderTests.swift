import Foundation
import Testing
@testable import GolfKit

struct OSMCourseBuilderTests {
    private func loadSample() throws -> OverpassResponse {
        let url = try #require(Bundle.module.url(
            forResource: "overpass_sample", withExtension: "json", subdirectory: "Data"))
        return try OverpassResponse.decode(from: Data(contentsOf: url))
    }

    @Test func buildsCourseWithNamePreference() throws {
        let courses = OSMCourseBuilder.build(from: try loadSample())
        #expect(courses.count == 1)
        let c = courses[0]
        #expect(c.id == "osm-way-1001")
        #expect(c.name == "範例高爾夫球場")
        #expect(c.county == "桃園市")
        #expect(c.source == .osm)
    }

    @Test func fallsBackToNameThenUnnamed() {
        let ring = [OverpassCoordinate(lat: 24, lon: 121), .init(lat: 24, lon: 121.01),
                    .init(lat: 24.01, lon: 121.01), .init(lat: 24, lon: 121)]
        let a = OverpassElement(type: .way, id: 1, tags: ["leisure": "golf_course", "name": "Foo"], geometry: ring)
        let b = OverpassElement(type: .way, id: 2, tags: ["leisure": "golf_course"], geometry: ring)
        let courses = OSMCourseBuilder.build(from: OverpassResponse(elements: [b, a]))
        #expect(courses.map(\.id) == ["osm-way-1", "osm-way-2"])
        #expect(courses[0].name == "Foo")
        #expect(courses[1].name == "未命名球場")
        #expect(courses[1].county == nil)
    }

    @Test func buildsHolesWithParAndGreens() throws {
        let c = try #require(OSMCourseBuilder.build(from: try loadSample()).first)
        #expect(c.holes.map(\.number) == [1, 2])
        #expect(c.holes[0].par == 4)
        #expect(c.holes[0].handicap == 7)
        #expect(c.holes[1].par == 3)
        for h in c.holes {
            #expect(h.tee != nil)
            #expect(h.green != nil)
            let center = try #require(h.greenCenter)
            let green = try #require(h.green)
            #expect(PolygonOps.contains(center, in: green))
        }
        #expect(c.hasHoleMaps)
    }

    @Test func assignsFeaturesToHolesOrCourse() throws {
        let c = try #require(OSMCourseBuilder.build(from: try loadSample()).first)
        let h1 = c.holes[0], h2 = c.holes[1]
        #expect(h1.features.contains { $0.kind == .fairway })
        #expect(h1.features.contains { $0.kind == .green })
        #expect(h1.features.contains { $0.kind == .tee })
        #expect(h2.features.contains { $0.kind == .bunker })
        #expect(h2.features.contains { $0.kind == .green })
        // Far-away water stays at course level; outside-course bunker is dropped.
        #expect(c.features.map(\.kind) == [.water])
        #expect(!c.holes.flatMap(\.features).contains { $0.kind == .water })
    }

    @Test func simplificationReducesPoints() throws {
        let response = try loadSample()
        let raw = try #require(response.elements.first { $0.id == 3003 }?.geometry)
        let c = try #require(OSMCourseBuilder.build(from: response).first)
        let fairway = try #require(c.holes[0].features.first { $0.kind == .fairway })
        #expect(fairway.polygon.count < raw.count)
        #expect(fairway.polygon.count >= 3)
        let rawPath = try #require(response.elements.first { $0.id == 2001 }?.geometry)
        #expect(c.holes[0].path.count < rawPath.count)
    }

    @Test func outputIsDeterministicAndEncodable() throws {
        let r = try loadSample()
        let a = try Course.encodeList(OSMCourseBuilder.build(from: r))
        let b = try Course.encodeList(OSMCourseBuilder.build(from: r))
        #expect(a == b)
        #expect(try Course.decodeList(from: a).count == 1)
    }

    @Test func relationUsesJoinedOuterRing() {
        func c(_ lat: Double, _ lon: Double) -> OverpassCoordinate { .init(lat: lat, lon: lon) }
        let m1 = OverpassMember(type: "way", ref: 1, role: "outer", geometry: [c(24, 121), c(24, 121.01), c(24.01, 121.01)])
        let m2 = OverpassMember(type: "way", ref: 2, role: "outer", geometry: [c(24, 121), c(24.01, 121), c(24.01, 121.01)])
        let rel = OverpassElement(type: .relation, id: 9, tags: ["leisure": "golf_course"], members: [m1, m2])
        let courses = OSMCourseBuilder.build(from: OverpassResponse(elements: [rel]))
        #expect(courses.first?.id == "osm-relation-9")
        #expect(abs((courses.first?.center.lat ?? 0) - 24.005) < 0.003)
    }

    @Test func queryMentionsBboxAndOutGeom() {
        #expect(OSMCourseBuilder.overpassQuery.contains("21.8,119.3,25.4,122.1"))
        #expect(OSMCourseBuilder.overpassQuery.contains("out geom;"))
    }
}
