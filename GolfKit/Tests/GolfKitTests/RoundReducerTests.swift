import Testing
import Foundation
@testable import GolfKit

struct RoundReducerTests {
    let rid = UUID()
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    let origin = GeoPoint(lat: 25.0, lon: 121.0)

    func at(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: origin) }

    func ev(_ sec: Double, _ kind: RoundEvent.Kind, id: UUID = UUID()) -> RoundEvent {
        RoundEvent(id: id, roundId: rid, timestamp: t0.addingTimeInterval(sec), source: .watch, kind: kind)
    }

    func stroke(_ h: Int = 1, _ t: RoundEvent.StrokeType = .swing, _ loc: GeoPoint? = nil) -> RoundEvent.Kind {
        .stroke(hole: h, type: t, location: loc, swing: nil)
    }

    var course: Course {
        let fairway = Feature(kind: .fairway, polygon: [at(-20, 150), at(20, 150), at(20, 250), at(-20, 250)])
        return Course(id: "c", name: "C", center: origin, holes: [
            Hole(number: 1, par: 4, tee: origin, greenCenter: at(0, 400), features: [fairway]),
            Hole(number: 2, par: 3, greenCenter: at(0, 150)),
        ])
    }

    @Test func holeTotalWithVoidPenaltyPutts() {
        let voidId = UUID()
        let events = [
            ev(0, stroke(1)), ev(1, stroke(1)), ev(2, stroke(1), id: voidId), ev(3, stroke(1)),
            ev(4, .void(strokeId: voidId)), ev(5, .penalty(hole: 1, count: 1)),
            ev(6, stroke(1, .putt)), ev(7, stroke(1, .putt)),
        ]
        let s = RoundReducer.reduce(events, course: course)
        let h = s.hole(1)
        #expect(h?.strokes == 5)
        #expect(h?.putts == 2)
        #expect(h?.penalties == 1)
        #expect(h?.total == 6)
        #expect(s.totalStrokes == 6)
        #expect(s.toPar == 2)
    }

    @Test func voidUnknownIdIgnored() {
        let s = RoundReducer.reduce([ev(0, stroke(1)), ev(1, .void(strokeId: UUID()))], course: nil)
        #expect(s.hole(1)?.strokes == 1)
    }

    @Test func distancesBetweenAndToGreen() throws {
        let events = [
            ev(0, stroke(1, .swing, at(0, 0))),
            ev(1, stroke(1, .swing, nil)),
            ev(2, stroke(1, .swing, at(0, 200))),
            ev(3, stroke(1, .swing, at(0, 380))),
        ]
        let shots = try #require(RoundReducer.reduce(events, course: course).hole(1)?.shots)
        #expect(abs(try #require(shots[0].distanceToNext) - 200) < 1)
        #expect(shots[1].distanceToNext == nil)
        #expect(abs(try #require(shots[2].distanceToNext) - 180) < 1)
        #expect(abs(try #require(shots[3].distanceToNext) - 20) < 1)
    }

    @Test func lastPuttHasNoGreenDistance() throws {
        let events = [ev(0, stroke(1, .swing, at(0, 380))), ev(1, stroke(1, .putt, at(0, 395)))]
        let shots = try #require(RoundReducer.reduce(events, course: course).hole(1)?.shots)
        #expect(shots[1].distanceToNext == nil)
    }

    @Test func mergeIdempotentAndOrderIndependent() {
        let a = [ev(0, stroke(1)), ev(1, stroke(1))]
        let b = [ev(2, stroke(1, .putt)), ev(1, .penalty(hole: 1, count: 1))]
        let all = a + b
        let m1 = merge(a, b)
        #expect(merge(m1, m1) == m1)
        #expect(merge(b, a) == m1)
        #expect(merge(m1, a) == m1)
        #expect(m1.count == 4)
        #expect(RoundReducer.reduce(all, course: nil) == RoundReducer.reduce(all.reversed() + a, course: nil))
    }

    @Test func currentHoleAndStartEnd() {
        let c0 = RoundReducer.reduce([ev(0, .start(courseId: "c")), ev(1, stroke(3))], course: nil)
        #expect(c0.currentHole == 3)
        #expect(c0.courseId == "c")
        #expect(c0.startedAt != nil && !c0.isEnded)
        let c1 = RoundReducer.reduce([ev(0, stroke(3)), ev(1, .goToHole(4)), ev(2, .end)], course: nil)
        #expect(c1.currentHole == 4)
        #expect(c1.isEnded)
        #expect(RoundReducer.reduce([], course: nil).currentHole == 1)
        #expect(RoundReducer.reduce([], course: nil).holes.count == 18)
        #expect(RoundReducer.reduce([], course: course).holes.count == 2)
    }

    @Test func setParOverridesAndToParSkipsNoPar() {
        let events = [ev(0, stroke(1)), ev(1, stroke(1)), ev(2, .setPar(hole: 1, par: 3)), ev(3, stroke(5)), ev(4, stroke(5))]
        let s = RoundReducer.reduce(events, course: course)
        #expect(s.hole(1)?.par == 3)
        #expect(s.toPar == -1)  // hole 5 has no par and is skipped
        #expect(RoundReducer.reduce([ev(0, stroke(5))], course: nil).toPar == nil)
    }

    @Test func clubAssignment() {
        let id = UUID()
        let s = RoundReducer.reduce([ev(0, stroke(1), id: id), ev(1, .setClub(strokeId: id, club: .driver))], course: nil)
        #expect(s.hole(1)?.shots.first?.club == .driver)
    }

    @Test func girAndStats() {
        // par 4: 2 shots then putt -> GIR; fairway hit by shot 2 location
        let good = [
            ev(0, stroke(1, .swing, at(0, 0))), ev(1, stroke(1, .swing, at(0, 200))),
            ev(2, stroke(1, .putt, at(0, 395))), ev(3, stroke(1, .putt, at(0, 399))),
        ]
        let s = RoundReducer.reduce(good, course: course)
        let st = RoundStats(state: s, course: course)
        #expect(st.girHits == 1 && st.girChances == 1)
        #expect(st.firHits == 1 && st.firChances == 1)
        #expect(st.totalPutts == 2)
        #expect(st.puttsPerHole == 2)
        #expect(st.girPercent == 100)

        // par 4: 3 shots before first putt -> no GIR; shot 2 outside fairway -> no FIR
        let bad = [
            ev(0, stroke(1, .swing, at(0, 0))), ev(1, stroke(1, .swing, at(100, 200))), ev(2, stroke(1, .swing, at(0, 380))),
            ev(3, stroke(1, .putt, at(0, 395))),
        ]
        let st2 = RoundStats(state: RoundReducer.reduce(bad, course: course), course: course)
        #expect(st2.girHits == 0 && st2.girChances == 1)
        #expect(st2.firHits == 0 && st2.firChances == 1)

        // par 3 hole: FIR not applicable
        let p3 = [ev(0, stroke(2, .swing, at(0, 0))), ev(1, stroke(2, .swing, at(0, 140))), ev(2, stroke(2, .putt, at(0, 150)))]
        let st3 = RoundStats(state: RoundReducer.reduce(p3, course: course), course: course)
        #expect(st3.firChances == 0 && st3.firPercent == nil)
        #expect(st3.girHits == 0)  // 1 stroke before putt? shot index 2 -> 2 > par-2=1
    }

    @Test func averageDistanceByClub() {
        let a = UUID(), b = UUID(), p = UUID()
        let events = [
            ev(0, stroke(1, .swing, at(0, 0)), id: a), ev(1, .setClub(strokeId: a, club: .driver)),
            ev(2, stroke(1, .swing, at(0, 200)), id: b), ev(3, .setClub(strokeId: b, club: .driver)),
            ev(4, stroke(1, .putt, at(0, 400)), id: p), ev(5, .setClub(strokeId: p, club: .putter)),
        ]
        let s = RoundReducer.reduce(events, course: course)
        let avg = RoundStats.averageDistanceByClub([s])
        #expect(avg[.putter] == nil)
        #expect(abs((avg[.driver] ?? 0) - 200) < 1)
    }

    @Test func eventCodableRoundTrip() throws {
        let kinds: [RoundEvent.Kind] = [
            .start(courseId: "c"), .stroke(hole: 2, type: .putt, location: GeoPoint(lat: 25.000001, lon: 121.000002), swing: SwingMetrics(peakRotation: 1, peakAccel: 2, tempo: 3)),
            .stroke(hole: 2, type: .manual, location: nil, swing: nil), .void(strokeId: UUID()), .penalty(hole: 1, count: 2),
            .setPar(hole: 1, par: 5), .setClub(strokeId: UUID(), club: .i7), .goToHole(9), .end,
        ]
        for k in kinds {
            let e = RoundEvent.make(roundId: rid, source: .phone, kind: k)
            let back = try JSONDecoder().decode(RoundEvent.self, from: JSONEncoder().encode(e))
            #expect(back.kind == e.kind && back.id == e.id)
        }
    }
}
