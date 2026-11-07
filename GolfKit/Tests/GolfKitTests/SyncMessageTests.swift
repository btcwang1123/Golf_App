import Testing
import Foundation
@testable import GolfKit

struct SyncMessageTests {
    let rid = UUID()
    let origin = GeoPoint(lat: 25.0, lon: 121.0)

    var course: Course {
        Course(id: "c", name: "C", center: origin, holes: [Hole(number: 1, par: 4, tee: origin, greenCenter: GeoPoint(lat: 25.002, lon: 121.0))])
    }

    func roundTrip(_ m: SyncMessage) throws {
        #expect(try SyncMessage(data: m.encoded()) == m)
        let dict = try m.encodedDictionary()
        #expect(dict.keys.contains(SyncMessage.payloadKey))
        #expect(try SyncMessage.decode(from: dict) == m)
    }

    @Test func roundTripAllCases() throws {
        let e = RoundEvent.make(roundId: rid, source: .watch, kind: .stroke(hole: 1, type: .swing, location: origin, swing: nil))
        try roundTrip(.events([e, RoundEvent.make(roundId: rid, source: .phone, kind: .end)]))
        try roundTrip(.course(course))
        try roundTrip(.startRound(roundId: rid, courseId: "c"))
        try roundTrip(.settings(AppSettings()))
        try roundTrip(.endRound(roundId: rid))
        try roundTrip(.requestCourse(courseId: "c"))
    }

    @Test func missingPayloadThrows() {
        #expect(throws: SyncMessage.SyncError.missingPayload) {
            try SyncMessage.decode(from: ["other": 1])
        }
    }

    @Test func duplicateDeliveryKeepsTotals() throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let evs = (0..<4).map { i in
            RoundEvent(roundId: rid, timestamp: t0.addingTimeInterval(Double(i)), source: .watch,
                       kind: .stroke(hole: 1, type: i == 3 ? .putt : .swing, location: nil, swing: nil))
        }
        let once = RoundReducer.reduce(evs, course: course)
        guard case .events(let received) = try SyncMessage.decode(from: SyncMessage.events(evs).encodedDictionary()) else {
            Issue.record("wrong case"); return
        }
        let merged = RoundReducer.merge(RoundReducer.merge(evs, received), received)
        #expect(merged.count == evs.count)
        let twice = RoundReducer.reduce(merged, course: course)
        #expect(twice.totalStrokes == once.totalStrokes)
        #expect(twice.totalStrokes == 4)
        #expect(twice.hole(1)?.putts == 1)
    }
}
