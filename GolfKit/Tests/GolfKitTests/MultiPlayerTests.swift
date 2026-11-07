import Testing
import Foundation
@testable import GolfKit

struct MultiPlayerTests {
    let rid = UUID()
    let amy = Player(name: "Amy", handicap: 10)
    let ben = Player(name: "Ben", handicap: 20)

    func ev(_ s: Double, _ k: RoundEvent.Kind, id: UUID = UUID()) -> RoundEvent { V2.ev(rid, s, k, id: id) }

    @Test func legacyRoundHasOnlyOwner() {
        let s = RoundReducer.reduce([ev(0, .start(courseId: "c")), ev(1, .stroke(hole: 1, type: .swing, location: nil, swing: nil))], course: nil)
        #expect(s.players.count == 1)
        #expect(s.players[0].isOwner)
        #expect(s.total(for: s.owner.id) == 1)
    }

    @Test func latestScoreWins() {
        let events = [
            ev(0, .addPlayer(amy)),
            ev(2, .playerScore(playerId: amy.id, hole: 1, strokes: 6, putts: 2)),
            ev(1, .playerScore(playerId: amy.id, hole: 1, strokes: 9, putts: nil)),
            ev(3, .setPar(hole: 1, par: 4)),
        ]
        let s = RoundReducer.reduce(events, course: nil)
        #expect(s.scores(for: amy.id)[1]?.strokes == 6)
        #expect(s.total(for: amy.id) == 6)
        #expect(s.toPar(for: amy.id) == 2)
    }

    @Test func removePlayerDropsScores() {
        let events = [ev(0, .addPlayer(amy)), ev(1, .addPlayer(ben)),
                      ev(2, .playerScore(playerId: amy.id, hole: 1, strokes: 5, putts: nil)),
                      ev(3, .removePlayer(amy.id))]
        let s = RoundReducer.reduce(events, course: nil)
        #expect(s.players.map(\.name) == ["我", "Ben"])
        #expect(s.scores(for: amy.id).isEmpty)
    }

    @Test func maxFourPlayers() {
        let events = (0..<5).map { ev(Double($0), .addPlayer(Player(name: "P\($0)"))) }
        #expect(RoundReducer.reduce(events, course: nil).players.count == Player.maxPerRound)
    }

    @Test func unknownKindDecodesAndIsIgnored() throws {
        let json = #"[{"id":"\#(UUID().uuidString)","roundId":"\#(rid.uuidString)","timestamp":0,"source":"phone","kind":{"type":"futureThing","x":1}}]"#
        let events = try JSONDecoder().decode([RoundEvent].self, from: Data(json.utf8))
        #expect(events.first?.kind == .unknown("futureThing"))
        let s = RoundReducer.reduce(events + [ev(1, .stroke(hole: 1, type: .putt, location: nil, swing: nil))], course: nil)
        #expect(s.totalStrokes == 1)
    }

    @Test func newKindsRoundTrip() throws {
        let kinds: [RoundEvent.Kind] = [
            .addPlayer(amy), .removePlayer(amy.id), .playerScore(playerId: amy.id, hole: 3, strokes: 4, putts: 1),
            .playerScore(playerId: amy.id, hole: 3, strokes: 4, putts: nil),
            .setPin(hole: 2, location: GeoPoint(lat: 25.0001, lon: 121.0002)), .setGame(GameFormat(kind: .skins, useHandicap: true)),
        ]
        for k in kinds {
            let e = ev(0, k)
            let back = try JSONDecoder().decode(RoundEvent.self, from: JSONEncoder().encode(e))
            #expect(back.kind == k)
        }
    }

    @Test func mergeIsIdempotent() {
        let a = [ev(0, .addPlayer(amy)), ev(1, .playerScore(playerId: amy.id, hole: 1, strokes: 5, putts: nil))]
        let b = [a[1], ev(2, .addPlayer(ben))]
        let m = RoundReducer.merge(a, b)
        #expect(m.count == 3)
        #expect(RoundReducer.merge(m, m) == m)
        #expect(RoundReducer.reduce(m, course: nil) == RoundReducer.reduce(RoundReducer.merge(b, a), course: nil))
    }
}
