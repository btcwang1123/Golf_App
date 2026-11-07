import Testing
import Foundation
@testable import GolfKit

struct OSMBuildingBuilderTests {
    /// ~20 m square with a redundant midpoint on one side, closed like an OSM way.
    func squareWay(id: Int64, tags: [String: String]) -> OverpassElement {
        let o = GeoPoint(lat: 25.0, lon: 121.5)
        let pts: [(Double, Double)] = [(0, 0), (10, 0), (20, 0), (20, 20), (0, 20), (0, 0)]
        let geom = pts.map { p -> OverpassCoordinate in
            let g = Geo.unproject(x: p.0, y: p.1, origin: o)
            return OverpassCoordinate(lat: g.lat, lon: g.lon)
        }
        return OverpassElement(type: .way, id: id, tags: tags, geometry: geom)
    }

    @Test func buildsSimplifiedFootprintWithHeight() throws {
        let response = OverpassResponse(elements: [
            squareWay(id: 1, tags: ["building": "yes", "building:levels": "3"]),
            squareWay(id: 2, tags: ["building": "house"]),
            squareWay(id: 3, tags: ["building": "yes", "height": "12 m"]),
        ])
        let buildings = OSMBuildingBuilder.buildings(from: response)
        #expect(buildings.count == 3)
        // Closing point and collinear midpoint dropped.
        #expect(buildings[0].footprint.count == 4)
        #expect(abs(buildings[0].height - (3 * OSMBuildingBuilder.metersPerLevel + 1)) < 0.01)
        #expect(buildings[1].height == 7)
        #expect(buildings[2].height == 12)
    }

    @Test func dropsTinyAndAssignsByBox() throws {
        let tiny = OverpassElement(type: .way, id: 9, tags: ["building": "yes"], geometry: [
            .init(lat: 25.0, lon: 121.5), .init(lat: 25.00001, lon: 121.5),
            .init(lat: 25.00001, lon: 121.50001), .init(lat: 25.0, lon: 121.5),
        ])
        let buildings = OSMBuildingBuilder.buildings(from: OverpassResponse(elements: [tiny, squareWay(id: 1, tags: [:])]))
        #expect(buildings.count == 1)
        let inBox = OSMBuildingBuilder.Box(south: 24.99, west: 121.49, north: 25.01, east: 121.51)
        let outBox = OSMBuildingBuilder.Box(south: 24.0, west: 120.0, north: 24.1, east: 120.1)
        #expect(OSMBuildingBuilder.assign(buildings, to: inBox).count == 1)
        #expect(OSMBuildingBuilder.assign(buildings, to: outBox).isEmpty)
    }

    @Test func compactCodingRoundTrips() throws {
        let b = Building(footprint: [GeoPoint(lat: 25.1234567, lon: 121.7654321), GeoPoint(lat: 25.2, lon: 121.8),
                                     GeoPoint(lat: 25.3, lon: 121.9)], height: 9.04)
        let data = try BuildingIndex.encode(["c": [b]])
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"p\":["))
        let back = try #require(try BuildingIndex.decode(from: data)["c"]?.first)
        #expect(back.footprint.count == 3)
        #expect(abs(back.footprint[0].lat - 25.123457) < 1e-9)
        #expect(back.height == 9.0)
    }
}
