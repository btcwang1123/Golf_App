import Testing
import Foundation
@testable import GolfKit

struct CourseQualityTests {
    @Test func fullHoleHasNoRequiredMissing() {
        let q = HoleQuality.evaluate(V2.fullHole())
        #expect(q.isComplete)
        #expect(q.missing.isEmpty)
        #expect(q.score == 1)
    }

    @Test func missingItemsDetected() {
        let q = HoleQuality.evaluate(Hole(number: 1, tee: V2.origin))
        #expect(q.missing.contains(.greenCenter))
        #expect(q.missing.contains(.greenPolygon))
        #expect(q.missing.contains(.par))
        #expect(q.missing.contains(.fairway))
        #expect(q.missing.contains(.hazards))
        #expect(q.missing.contains(.handicap))
        #expect(!q.missing.contains(.tee))
        #expect(q.level == .scoreOnly)
    }

    @Test func levels() {
        #expect(CourseQuality.evaluate(V2.course()).level == .full)
        // Half the holes playable → partial.
        var c = V2.course(holes: 4)
        c.holes[0].green = nil
        c.holes[2] = Hole(number: 3, par: 4)
        c.holes[3] = Hole(number: 4, par: 4)
        #expect(CourseQuality.evaluate(c).level == .partial)
        c.holes[1] = Hole(number: 2, par: 4)
        #expect(CourseQuality.evaluate(c).level == .scoreOnly)
        #expect(CourseQuality.evaluate(Course(id: "x", name: "x", center: V2.origin)).level == .scoreOnly)
    }

    @Test func optionalItemsDoNotBlockFull() {
        var c = V2.course(holes: 2)
        c.holes = c.holes.map { var h = $0; h.features = []; h.handicap = nil; return h }
        let q = CourseQuality.evaluate(c)
        #expect(q.level == .full)
        #expect(q.score < 1)
        #expect(q.missingRequiredCount == 0)
    }

    @Test func legacySourceDecodes() throws {
        let json = #"{"id":"a","name":"A","center":{"lat":25,"lon":121},"source":"user"}"#
        let c = try JSONDecoder().decode(Course.self, from: Data(json.utf8))
        #expect(c.source == .user)
        #expect(c.provenance == nil)
        #expect(c.effectiveProvenance == .userTraced)
        let featured = #"{"id":"f","name":"F","center":{"lat":25,"lon":121},"source":"featured","provenance":"survey","replaces":"osm-1"}"#
        let f = try JSONDecoder().decode(Course.self, from: Data(featured.utf8))
        #expect(f.source == .featured && f.provenance == .survey && f.replaces == "osm-1")
        let future = #"{"id":"z","name":"Z","center":{"lat":25,"lon":121},"source":"partner","provenance":"drone"}"#
        let z = try JSONDecoder().decode(Course.self, from: Data(future.utf8))
        #expect(z.source == .osm && z.provenance == nil)
    }
}
