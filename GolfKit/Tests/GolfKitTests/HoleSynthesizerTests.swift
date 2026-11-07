import Testing
import Foundation
@testable import GolfKit

struct HoleSynthesizerTests {
    let origin = GeoPoint(lat: 23.0, lon: 120.3)

    func p(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: origin) }

    /// Square green, `side` m wide, centered at (x, y).
    func green(_ x: Double, _ y: Double, side: Double = 22) -> Feature {
        let h = side / 2
        return Feature(kind: .green, polygon: [p(x - h, y - h), p(x + h, y - h), p(x + h, y + h), p(x - h, y + h)])
    }

    func fairway(x: Double, from a: Double, to b: Double) -> Feature {
        Feature(kind: .fairway, polygon: [p(x - 20, a), p(x + 20, a), p(x + 20, b), p(x - 20, b)])
    }

    func course(_ features: [Feature], name: String = "測試球場", holes: [Hole] = []) -> Course {
        Course(id: "t", name: name, center: origin, holes: holes, features: features)
    }

    @Test func eachGreenBecomesHoleWithPinAtCenter() throws {
        let c = HoleSynthesizer.apply(to: course([green(0, 350), green(100, 0), fairway(x: 0, from: 0, to: 330)]))
        #expect(c.holes.count == 2)
        let withTee = try #require(c.holes.first { $0.tee != nil })
        #expect(Geo.distance(try #require(withTee.greenCenter), p(0, 350)) < 1)
        #expect(withTee.par == 4)
        #expect(withTee.green != nil)
        #expect(CourseQuality.evaluate(c).level != .scoreOnly)
    }

    @Test func twinGreensMergeIntoOneHole() {
        let c = HoleSynthesizer.apply(to: course([green(0, 0), green(30, 0, side: 20), green(400, 0)]))
        #expect(c.holes.count == 2)
    }

    @Test func numbersFollowWalkingRoute() throws {
        // Hole A: tee (0,0) → green (0,350); hole B: tee (40,360) → green (40,700).
        let c = HoleSynthesizer.apply(to: course([
            green(40, 720), green(0, 350),
            fairway(x: 0, from: 0, to: 330), fairway(x: 40, from: 370, to: 700),
        ]))
        let first = try #require(c.hole(1)?.greenCenter)
        #expect(Geo.distance(first, p(0, 350)) < 1)
    }

    @Test func leavesCoursesAloneWhenNotApplicable() {
        let hole = Hole(number: 1, greenCenter: p(0, 0))
        #expect(HoleSynthesizer.apply(to: course([green(0, 0), green(300, 0)], holes: [hole])).holes == [hole])
        #expect(HoleSynthesizer.apply(to: course([green(0, 0), green(300, 0)], name: "某某練習場")).holes.isEmpty)
        #expect(HoleSynthesizer.apply(to: course([green(0, 0)])).holes.isEmpty)
        #expect(HoleSynthesizer.apply(to: course([green(0, 0, side: 200), green(300, 0, side: 5)])).holes.isEmpty)
    }

    @Test func bundledCoursesGetHoles() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("GolfApp/Resources/courses_tw.json")
        guard let data = try? Data(contentsOf: url) else { return }
        let list = HoleSynthesizer.apply(to: try Course.decodeList(from: data))
        let names = ["空軍清泉崗高爾夫球場", "南一高爾夫鄉村俱樂部", "台北高爾夫俱樂部球場", "大屯高爾夫球場"]
        for n in names {
            let c = try #require(list.first { $0.name == n })
            #expect(c.holes.count >= 9, "\(n): \(c.holes.count) holes")
        }
    }
}
