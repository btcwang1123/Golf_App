import Testing
import Foundation
@testable import GolfKit

struct GameScorerTests {
    let rid = UUID()
    let a = Player(name: "A", handicap: 0)
    let b = Player(name: "B", handicap: 18)

    func ev(_ s: Double, _ k: RoundEvent.Kind) -> RoundEvent { V2.ev(rid, s, k) }

    func state(_ game: GameFormat, scores: [(Player, Int, Int)], holes: Int = 18) -> RoundState {
        var events = [ev(0, .start(courseId: "c")), ev(1, .addPlayer(a)), ev(2, .addPlayer(b)), ev(3, .setGame(game))]
        var t = 10.0
        for (p, h, n) in scores { events.append(ev(t, .playerScore(playerId: p.id, hole: h, strokes: n, putts: nil))); t += 1 }
        return RoundReducer.reduce(events, course: V2.course(holes: holes))
    }

    @Test func stablefordPoints() {
        #expect(GameScorer.stablefordPoints(net: 6, par: 4) == 0)
        #expect(GameScorer.stablefordPoints(net: 5, par: 4) == 1)
        #expect(GameScorer.stablefordPoints(net: 4, par: 4) == 2)
        #expect(GameScorer.stablefordPoints(net: 3, par: 4) == 3)
        #expect(GameScorer.stablefordPoints(net: 2, par: 4) == 4)
    }

    @Test func handicapAllocation() {
        #expect(HandicapAllocator.strokes(handicap: 18, holeHandicap: 7, holeCount: 18) == 1)
        #expect(HandicapAllocator.strokes(handicap: 10, holeHandicap: 10, holeCount: 18) == 1)
        #expect(HandicapAllocator.strokes(handicap: 10, holeHandicap: 11, holeCount: 18) == 0)
        #expect(HandicapAllocator.strokes(handicap: 20, holeHandicap: 2, holeCount: 18) == 2)
        let spread = (1...18).map { HandicapAllocator.strokes(handicap: 9, holeHandicap: nil, holeCount: 18, holeNumber: $0) }
        #expect(spread.reduce(0, +) == 9)
        #expect(spread.max() == 1)
    }

    @Test func stablefordWithHandicap() {
        // Both par 4: A gross 4 (2 pts), B gross 5 net 4 (2 pts).
        let s = state(GameFormat(kind: .stableford, useHandicap: true), scores: [(a, 1, 4), (b, 1, 5)])
        let st = GameScorer.standings(state: s, course: V2.course())
        #expect(st.first { $0.playerId == a.id }?.value == 2)
        #expect(st.first { $0.playerId == b.id }?.value == 2)
        #expect(st.filter { $0.holesPlayed > 0 }.allSatisfy { $0.rank == 1 })
    }

    @Test func matchPlayStatus() {
        // Only A & B (owner removed is impossible), so build a 2-player state from the owner + A.
        var events = [ev(0, .start(courseId: "c")), ev(1, .addPlayer(a)), ev(2, .setGame(GameFormat(kind: .match)))]
        var t = 10.0
        for h in 1...16 {
            events.append(ev(t, .stroke(hole: h, type: .swing, location: nil, swing: nil))); t += 1
            for _ in 0..<(h <= 3 ? 4 : 3) { events.append(ev(t, .stroke(hole: h, type: .swing, location: nil, swing: nil))); t += 1 }
            events.append(ev(t, .playerScore(playerId: a.id, hole: h, strokes: 4, putts: nil))); t += 1
        }
        // Owner: 5 on 1-3 (lose), 4 on 4-16 (halve) → A is 3 UP with 2 to play → 3&2.
        let s = RoundReducer.reduce(events, course: V2.course())
        let st = GameScorer.standings(state: s, course: V2.course())
        #expect(st.first { $0.playerId == a.id }?.detail == "3&2")
        #expect(st.first?.playerId == a.id)
        #expect(GameScorer.matchStatus(up: 2, remaining: 5) == "2 UP")
        #expect(GameScorer.matchStatus(up: -1, remaining: 5) == "1 DN")
        #expect(GameScorer.matchStatus(up: 0, remaining: 5) == "AS")
        #expect(!GameFormat.Kind.match.allows(playerCount: 3))
    }

    @Test func skinsCarryOver() {
        // Hole 1 tie (carry), hole 2 B wins 2 skins. Owner has no score so skins need all three… use owner too.
        var events = [ev(0, .start(courseId: "c")), ev(1, .addPlayer(a)), ev(2, .addPlayer(b)), ev(3, .setGame(GameFormat(kind: .skins)))]
        var t = 10.0
        func owner(_ h: Int, _ n: Int) { for _ in 0..<n { events.append(ev(t, .stroke(hole: h, type: .swing, location: nil, swing: nil))); t += 1 } }
        func score(_ p: Player, _ h: Int, _ n: Int) { events.append(ev(t, .playerScore(playerId: p.id, hole: h, strokes: n, putts: nil))); t += 1 }
        owner(1, 4); score(a, 1, 4); score(b, 1, 5)
        owner(2, 5); score(a, 2, 5); score(b, 2, 3)
        let s = RoundReducer.reduce(events, course: V2.course())
        let st = GameScorer.standings(state: s, course: V2.course())
        #expect(st.first { $0.playerId == b.id }?.value == 2)
        #expect(st.first?.playerId == b.id)
    }

    @Test func strokePlayRanksByNetToPar() {
        let s = state(GameFormat(kind: .stroke), scores: [(a, 1, 4), (b, 1, 6)])
        let st = GameScorer.standings(state: s, course: V2.course())
        #expect(st.first?.playerId == a.id)
        #expect(st.first { $0.playerId == b.id }?.value == 2)
    }
}
