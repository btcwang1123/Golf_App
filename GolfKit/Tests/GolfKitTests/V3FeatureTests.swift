import Foundation
import Testing
@testable import GolfKit

private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
private let origin = GeoPoint(lat: 25.0, lon: 121.0)
private func at(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: origin) }

/// Round where every player's hole scores are given; the owner's come from strokes.
private func groupRound(pars: [Int], scores: [[Int]], handicaps: [Int?]? = nil, bets: BetConfig? = nil,
                        wolf: [Int: Int?] = [:]) -> (RoundState, [Player]) {
    let rid = UUID()
    var t = t0
    var evs: [RoundEvent] = []
    func add(_ k: RoundEvent.Kind) { evs.append(RoundEvent(roundId: rid, timestamp: t, source: .phone, kind: k)); t += 1 }
    add(.start(courseId: "c"))
    var players: [Player] = [.owner(handicap: handicaps?[0] ?? nil)]
    if let h = handicaps?[0] { add(.addPlayer(.owner(handicap: h))) }
    for i in 1..<scores.count {
        let p = Player(name: "P\(i)", handicap: handicaps?[i] ?? nil)
        players.append(p)
        add(.addPlayer(p))
    }
    for (h, par) in pars.enumerated() { add(.setPar(hole: h + 1, par: par)) }
    for hole in pars.indices {
        let n = hole + 1
        for _ in 0..<scores[0][hole] { add(.stroke(hole: n, type: .manual, location: nil, swing: nil)) }
        for i in 1..<scores.count { add(.playerScore(playerId: players[i].id, hole: n, strokes: scores[i][hole], putts: nil)) }
    }
    if let bets { add(.setBets(bets)) }
    for (h, partner) in wolf { add(.wolfPick(hole: h, partnerId: partner.map { players[$0].id })) }
    return (RoundReducer.reduce(evs, course: nil), players)
}

struct EventCompatibilityTests {
    @Test func penaltyReasonRoundTripsAndOldEventsDecode() throws {
        let e = RoundEvent(roundId: UUID(), source: .phone, kind: .penalty(hole: 3, count: 1, reason: .water))
        let back = try JSONDecoder().decode(RoundEvent.self, from: JSONEncoder().encode(e))
        #expect(back == e)
        let old = #"{"type":"penalty","hole":2,"count":2}"#.data(using: .utf8)!
        #expect(try JSONDecoder().decode(RoundEvent.Kind.self, from: old) == .penalty(hole: 2, count: 2))
        let bad = #"{"type":"penalty","hole":2,"count":1,"reason":"meteor"}"#.data(using: .utf8)!
        #expect(try JSONDecoder().decode(RoundEvent.Kind.self, from: bad) == .penalty(hole: 2, count: 1, reason: nil))
    }

    @Test func newKindsRoundTrip() throws {
        let kinds: [RoundEvent.Kind] = [
            .setBets(BetConfig(stakes: [.init(game: .skins, amount: 100)], useHandicap: true, vegasTeam: [UUID()])),
            .wolfPick(hole: 4, partnerId: UUID()), .wolfPick(hole: 5, partnerId: nil),
        ]
        for k in kinds { #expect(try JSONDecoder().decode(RoundEvent.Kind.self, from: JSONEncoder().encode(k)) == k) }
    }

    @Test func reducerKeepsPenaltyReasons() {
        let rid = UUID()
        let evs = [
            RoundEvent(roundId: rid, timestamp: t0, source: .phone, kind: .stroke(hole: 1, type: .swing, location: nil, swing: nil)),
            RoundEvent(roundId: rid, timestamp: t0 + 1, source: .phone, kind: .penalty(hole: 1, count: 1, reason: .outOfBounds)),
            RoundEvent(roundId: rid, timestamp: t0 + 2, source: .phone, kind: .penalty(hole: 1, count: 1)),
        ]
        let h = RoundReducer.reduce(evs, course: nil).hole(1)
        #expect(h?.penalties == 2)
        #expect(h?.penaltyReasons == [.outOfBounds])
    }

    @Test func practiceSyncMessageRoundTrips() throws {
        let s = PracticeSession(startedAt: t0, endedAt: t0 + 600, club: .i7,
                                swings: [.init(timestamp: t0 + 10, metrics: SwingMetrics(peakRotation: 20, peakAccel: 5, tempo: 3.1))])
        let msg = SyncMessage.practice(s)
        #expect(try SyncMessage(data: msg.encoded()) == msg)
    }
}

struct BetSettlementTests {
    func config(_ g: BetConfig.Game, _ amount: Int = 100) -> BetConfig { BetConfig(stakes: [.init(game: g, amount: amount)]) }

    @Test func perStrokePaysDifference() {
        let (s, p) = groupRound(pars: [4, 4, 4], scores: [[4, 4, 4], [5, 5, 4], [4, 6, 6]], bets: config(.perStroke))
        let r = BetSettlement.compute(state: s, course: nil)
        // me 12, P1 14, P2 16: me +2+4, P1 -2+2, P2 -4-2
        #expect(r.totals[p[0].id] == 600)
        #expect(r.totals[p[1].id] == 0)
        #expect(r.totals[p[2].id] == -600)
        #expect(r.totals.values.reduce(0, +) == 0)
        #expect(r.transfers == [.init(from: p[2].id, to: p[0].id, amount: 600)])
    }

    @Test func skinsCarryOver() {
        let (s, p) = groupRound(pars: [4, 4, 4], scores: [[4, 4, 5], [4, 5, 6], [5, 5, 6]], bets: config(.skins, 50))
        let r = BetSettlement.compute(state: s, course: nil)
        // hole1 tie (carry), hole2 me alone → 2 skins, hole3 me → 1. 3 skins × 50 × 2 others
        #expect(r.totals[p[0].id] == 300)
        #expect(r.totals[p[1].id] == -150)
        #expect(r.games.first?.notes[p[0].id] == "3 skins")
    }

    @Test func handicapNetsBeforeComparing() {
        var c = config(.perStroke)
        c.useHandicap = true
        // P1 gets 18 strokes over 18 holes relative to me: one per hole.
        let (s, p) = groupRound(pars: Array(repeating: 4, count: 18),
                                scores: [Array(repeating: 4, count: 18), Array(repeating: 5, count: 18)],
                                handicaps: [0, 18], bets: c)
        let r = BetSettlement.compute(state: s, course: nil)
        #expect(r.totals[p[0].id] == 0)
    }

    @Test func nassauThreeBets() {
        let front = Array(repeating: 4, count: 9)
        let (s, p) = groupRound(pars: front + front, scores: [front + Array(repeating: 6, count: 9), Array(repeating: 5, count: 18)],
                                bets: config(.nassau))
        let r = BetSettlement.compute(state: s, course: nil)
        // me wins front (36 v 45), loses back (54 v 45), wins total (90 v 90 → tie).
        #expect(r.totals[p[0].id] == 0)
        #expect(r.games[0].notes[p[0].id] == "贏 1 注")
    }

    @Test func birdieBonus() {
        let (s, p) = groupRound(pars: [4, 5, 3], scores: [[3, 3, 3], [4, 5, 3], [4, 5, 4]], bets: config(.birdie, 20))
        // me: birdie (1) + eagle (2) = 3 points, collects 60 from each of 2.
        let r = BetSettlement.compute(state: s, course: nil)
        #expect(r.totals[p[0].id] == 120)
        #expect(r.totals[p[2].id] == -60)
    }

    @Test func vegasNumbers() {
        #expect(BetSettlement.vegasNumber(5, 4, flipped: false) == 45)
        #expect(BetSettlement.vegasNumber(5, 4, flipped: true) == 54)
        #expect(BetSettlement.vegasNumber(4, 10, flipped: false) == 410)
    }

    @Test func vegasTeamsSettle() {
        // Team A me+P1: 4,5 → 45; team B P2+P3: 5,6 → 56. Diff 11 points.
        let (s, p) = groupRound(pars: [4], scores: [[4], [5], [5], [6]], bets: config(.vegas, 10))
        let r = BetSettlement.compute(state: s, course: nil)
        #expect(r.totals[p[0].id] == 110)
        #expect(r.totals[p[1].id] == 110)
        #expect(r.totals[p[2].id] == -110)
        #expect(r.totals[p[3].id] == -110)
    }

    @Test func vegasBirdieFlipsOpponent() {
        // Team A has a birdie (3): 35; team B 5,6 flips to 65. Diff 30.
        let (s, p) = groupRound(pars: [4], scores: [[3], [5], [5], [6]], bets: config(.vegas, 1))
        #expect(BetSettlement.compute(state: s, course: nil).totals[p[0].id] == 30)
    }

    @Test func wolfLoneAndPartner() {
        // Hole 1 wolf = me, partner P1; best 4 vs 5 → we win; each loser pays each winner 10.
        // Hole 2 wolf = P1 alone; P1 3 vs best 4 → P1 collects 20 from each of 3.
        let (s, p) = groupRound(pars: [4, 4], scores: [[4, 4], [5, 3], [5, 4], [6, 5]],
                                bets: config(.wolf, 10), wolf: [1: 1, 2: nil])
        let r = BetSettlement.compute(state: s, course: nil)
        #expect(r.totals[p[0].id] == 20 - 20)
        #expect(r.totals[p[1].id] == 20 + 60)
        #expect(r.totals[p[2].id] == -20 - 20)
        #expect(r.totals.values.reduce(0, +) == 0)
        #expect(BetSettlement.wolf(on: 5, players: p)?.id == p[0].id)
    }

    @Test func vegasIgnoredWithoutFourPlayers() {
        let (s, _) = groupRound(pars: [4], scores: [[4], [5]], bets: config(.vegas))
        #expect(BetSettlement.compute(state: s, course: nil).games.isEmpty)
    }

    @Test func minimalTransfersSettleEveryone() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        let t = BetSettlement.minimalTransfers([a: 300, b: -100, c: -250, d: 50])
        var net: [UUID: Int] = [:]
        for x in t { net[x.from, default: 0] -= x.amount; net[x.to, default: 0] += x.amount }
        #expect(net[a] == 300 && net[b] == -100 && net[c] == -250 && net[d] == 50)
        #expect(t.count <= 3)
    }
}

struct AchievementTests {
    func round(_ scores: [Int], pars: [Int]? = nil, start: Date = t0, putts: Int = 2, players: Int = 1) -> RoundState {
        let rid = UUID()
        var t = start
        var evs: [RoundEvent] = []
        func add(_ k: RoundEvent.Kind) { evs.append(RoundEvent(roundId: rid, timestamp: t, source: .phone, kind: k)); t += 1 }
        add(.start(courseId: "c\(scores.count)"))
        for i in 1..<players { add(.addPlayer(Player(name: "F\(i)"))) }
        let ps = pars ?? Array(repeating: 4, count: scores.count)
        for (i, s) in scores.enumerated() {
            add(.setPar(hole: i + 1, par: ps[i]))
            let p = min(putts, s)
            for _ in 0..<(s - p) { add(.stroke(hole: i + 1, type: .swing, location: nil, swing: nil)) }
            for _ in 0..<p { add(.stroke(hole: i + 1, type: .putt, location: nil, swing: nil)) }
        }
        add(.end)
        return RoundReducer.reduce(evs, course: nil)
    }

    @Test func singleRoundMilestones() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        // 1_700_000_000 = 22:13 UTC; use an early start.
        let early = Date(timeIntervalSince1970: 1_700_020_000) // 03:46 UTC
        let scores = [3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
        let got = AchievementEngine.earned(by: round(scores, start: early, players: 2), calendar: utc)
        #expect(got.isSuperset(of: [.firstRound, .firstBirdie, .birdieStreak2, .parStreak5, .break90, .break100,
                                    .noThreePutts, .noPenalties, .firstGroupRound, .earlyBird]))
        #expect(!got.contains(.break80))
        #expect(!got.contains(.firstEagle))
    }

    @Test func holeInOneOnlyOnPar3() {
        let r = round([1, 4], pars: [3, 4], putts: 0)
        #expect(AchievementEngine.earned(by: r).contains(.holeInOne))
        #expect(!AchievementEngine.earned(by: r).contains(.break100))
    }

    @Test func unlocksAreFirstOccurrenceAndCount() {
        let rounds = (0..<10).map { i in round(Array(repeating: 6, count: 18), start: t0 + Double(i) * 86_400) }
        let u = AchievementEngine.unlocks(rounds: rounds)
        #expect(u.first { $0.achievement == .firstRound }?.roundId == rounds[0].roundId)
        #expect(u.first { $0.achievement == .rounds10 }?.roundId == rounds[9].roundId)
        #expect(AchievementEngine.newlyUnlocked(in: rounds[9].roundId, rounds: rounds).map(\.achievement) == [.rounds10])
    }
}

struct RecapTests {
    @Test func yearRecap() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let a = AchievementTests()
        let jan = cal.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 8))!
        let feb = cal.date(from: DateComponents(year: 2026, month: 2, day: 10, hour: 8))!
        let old = cal.date(from: DateComponents(year: 2025, month: 6, day: 1, hour: 8))!
        let rounds = [
            a.round(Array(repeating: 5, count: 18), start: jan),
            a.round([3] + Array(repeating: 4, count: 17), start: feb),
            a.round(Array(repeating: 4, count: 9), start: feb + 86_400),
            a.round(Array(repeating: 7, count: 18), start: old),
        ]
        #expect(PeriodRecap.availablePeriods(rounds: rounds, calendar: cal).prefix(2) == [.year(2026), .month(year: 2026, month: 2)])
        let r = PeriodRecap.make(period: .year(2026), rounds: rounds, calendar: cal)
        #expect(r.roundCount == 3)
        #expect(r.best18?.strokes == 71)
        #expect(r.best9?.strokes == 36)
        #expect(r.birdies == 1)
        #expect(r.busiestMonth?.month == 2)
        #expect(r.coursesPlayed == 2)
        let m = PeriodRecap.make(period: .month(year: 2026, month: 1), rounds: rounds, calendar: cal)
        #expect(m.roundCount == 1)
        #expect(m.busiestMonth == nil)
    }
}

struct ShortGameAndTempoTests {
    @Test func upAndDownSandSaveAndPutts() {
        let green = Polygon([at(-10, 290), at(10, 290), at(10, 310), at(-10, 310)])
        let bunker = Feature(kind: .bunker, polygon: [at(15, 290), at(30, 290), at(30, 310), at(15, 310)])
        let course = Course(id: "c", name: "C", center: origin, holes: [
            Hole(number: 1, par: 4, tee: origin, greenCenter: at(0, 300), green: green, features: [bunker]),
            Hole(number: 2, par: 4, tee: origin, greenCenter: at(0, 300), green: green),
        ])
        let rid = UUID()
        var t = t0
        var evs: [RoundEvent] = []
        func add(_ k: RoundEvent.Kind) { evs.append(RoundEvent(roundId: rid, timestamp: t, source: .phone, kind: k)); t += 1 }
        add(.start(courseId: "c"))
        // Hole 1: drive, approach into bunker, splash out, 1 putt from 2 m = par, sand save.
        add(.stroke(hole: 1, type: .swing, location: origin, swing: nil))
        add(.stroke(hole: 1, type: .swing, location: at(0, 150), swing: nil))
        add(.stroke(hole: 1, type: .swing, location: at(20, 300), swing: nil))
        add(.stroke(hole: 1, type: .putt, location: at(0, 302), swing: nil))
        // Hole 2: GIR, three putts from 8 m, OB penalty.
        add(.stroke(hole: 2, type: .swing, location: origin, swing: nil))
        add(.penalty(hole: 2, count: 1, reason: .outOfBounds))
        add(.stroke(hole: 2, type: .swing, location: at(0, 150), swing: nil))
        for _ in 0..<3 { add(.stroke(hole: 2, type: .putt, location: at(0, 308), swing: nil)) }
        let s = RoundReducer.reduce(evs, course: course)
        let st = ShortGameStats.make(rounds: [s], courses: ["c": course])
        #expect(st.upAndDown == .init(made: 1, chances: 2))
        #expect(st.sandSave == .init(made: 1, chances: 1))
        #expect(st.onePutts == 1 && st.threePutts == 1)
        #expect(st.penaltiesByReason[.outOfBounds] == 1)
        #expect(st.puttBuckets[1].made == 1)
        #expect(st.puttBuckets[3].threePutts == 1)
    }

    @Test func tempoStats() {
        let t = TempoStats.make([(3.0, .driver), (3.2, .driver), (2.0, .i7), (20, nil)])
        #expect(t.count == 3)
        #expect(abs((t.average ?? 0) - 2.733) < 0.01)
        #expect(abs((t.idealShare ?? 0) - 2.0 / 3) < 0.001)
        #expect(t.byClub[.driver] == 3.1)
        #expect(TempoStats.rating(2.0) == .quick)
        #expect(TempoStats.rating(3.0) == .ideal)
    }

    @Test func practiceSessionCounts() {
        let m = SwingMetrics(peakRotation: 1, peakAccel: 1, tempo: 3)
        let s = PracticeSession(startedAt: t0, club: .i7, swings: [
            .init(timestamp: t0 + 30, metrics: m), .init(timestamp: t0 + 60, metrics: m, club: .driver),
        ])
        #expect(s.countsByClub[.i7] == 1 && s.countsByClub[.driver] == 1)
        #expect(s.duration == 60)
    }
}

struct PaceAndPlanTests {
    @Test func paceOfPlay() {
        let rid = UUID()
        var evs = [RoundEvent(roundId: rid, timestamp: t0, source: .phone, kind: .start(courseId: "c"))]
        for h in 1...3 {
            let start = t0 + Double(h - 1) * 20 * 60
            evs.append(RoundEvent(roundId: rid, timestamp: start, source: .phone, kind: .stroke(hole: h, type: .swing, location: nil, swing: nil)))
            evs.append(RoundEvent(roundId: rid, timestamp: start + 600, source: .phone, kind: .stroke(hole: h, type: .putt, location: nil, swing: nil)))
        }
        let s = RoundReducer.reduce(evs, course: nil)
        let pace = PaceOfPlay(state: s, now: t0 + 60 * 60)
        #expect(pace.holeSeconds[1] == 1200)
        #expect(pace.holeSeconds[3] == 600)
        #expect(pace.holesCompleted == 3)
        #expect(pace.status() == .behind(minutes: 18))
        #expect(PaceOfPlay.format(4 * 3600 + 12 * 60) == "4:12")
    }

    @Test func planMiss() {
        let plan = HolePlan(courseId: "c", hole: 1, targets: [at(0, 200)], clubs: [.driver])
        var h = HoleState(number: 1)
        h.shots = [ShotInfo(id: UUID(), type: .swing, location: origin, timestamp: t0),
                   ShotInfo(id: UUID(), type: .swing, location: at(30, 200), timestamp: t0)]
        #expect(abs((plan.teeShotMiss(h) ?? 0) - 30) < 0.5)
        #expect(plan.club(for: 1) == nil)
        #expect(HolePlan(courseId: "c", hole: 2).isEmpty)
    }

    @Test func teeTimeReminders() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let tee = cal.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 7))!
        let tt = TeeTime(courseId: "c", courseName: "C", date: tee, reminderMinutes: 60)
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9))!
        let r = tt.reminderDates(now: now, calendar: cal)
        #expect(r.evening == cal.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 20)))
        #expect(r.before == tee - 3600)
        #expect(tt.reminderDates(now: tee, calendar: cal).before == nil)
        #expect(TeeTime.upcoming([tt], now: tee + 7 * 3600).isEmpty)
    }
}

struct ScorecardParserTests {
    /// Builds a printed table: label column at x 0.05, holes at 0.15 + 0.08·i.
    func row(_ label: String?, _ values: [Int], y: Double, offset: Int = 0, mergeIntoOne: Bool = false) -> [OCRToken] {
        var out: [OCRToken] = []
        if let label { out.append(OCRToken(text: label, minX: 0.01, maxX: 0.09, midY: y, height: 0.03)) }
        if mergeIntoOne {
            out.append(OCRToken(text: values.map(String.init).joined(separator: " "), minX: 0.15 - 0.03,
                                maxX: 0.15 + 0.08 * Double(values.count - 1) + 0.03, midY: y, height: 0.03))
        } else {
            for (i, v) in values.enumerated() {
                let x = 0.15 + 0.08 * Double(i + offset)
                out.append(OCRToken(text: "\(v)", minX: x - 0.01, maxX: x + 0.01, midY: y + (i.isMultiple(of: 2) ? 0.003 : -0.003), height: 0.03))
            }
        }
        return out
    }

    @Test func parsesFrontAndBack() throws {
        var tokens: [OCRToken] = []
        tokens += row("HOLE", Array(1...9), y: 0.10)
        tokens += row("PAR", [4, 4, 3, 5, 4, 4, 3, 4, 5], y: 0.14)
        tokens += row("HCP", [7, 3, 17, 1, 9, 11, 15, 5, 13], y: 0.18)
        tokens += row("小明", [5, 4, 3, 6, 5, 5, 4, 4, 6], y: 0.22, mergeIntoOne: true)
        tokens += row("阿華", [6, 5, 4, 7, 5, 6, 3, 5, 6], y: 0.26)
        tokens += row("HOLE", Array(10...18), y: 0.50)
        tokens += row("PAR", [4, 3, 4, 5, 4, 4, 3, 5, 4], y: 0.54)
        tokens += row("小明", [4, 3, 5, 5, 4, 5, 3, 6, 5], y: 0.58)
        tokens += row("阿華", [5, 4, 5, 6, 5, 4, 4, 6, 5], y: 0.62)
        let card = try #require(ScorecardParser.parse(tokens))
        #expect(card.holes == Array(1...18))
        #expect(card.pars[4] == 5 && card.pars[16] == 3)
        #expect(card.rows.count == 2)
        #expect(card.rows[0].label == "小明")
        #expect(card.rows[0].scores[1] == 5 && card.rows[0].scores[18] == 5)
        #expect(card.rows[0].scores.count == 18)
        #expect(card.rows[1].scores[7] == 3)
    }

    @Test func skipsYardageAndToleratesMissingHoleNumber() throws {
        var tokens = row(nil, [1, 2, 3, 5, 6, 7, 8, 9], y: 0.1).enumerated().map { i, t -> OCRToken in
            var t = t
            if i >= 3 { t.minX += 0.08; t.maxX += 0.08 } // hole 4 missing from OCR
            return t
        }
        tokens += row("YARDS", [380, 402, 165, 520, 390, 410, 180, 395, 505], y: 0.14)
        tokens += row(nil, [5, 5, 3, 6, 4, 5, 4, 4, 6], y: 0.18)
        let card = try #require(ScorecardParser.parse(tokens))
        #expect(card.holes == Array(1...9))
        try #require(card.rows.count == 1)
        #expect(card.rows[0].scores[4] == 6)
        #expect(card.pars.isEmpty)
    }

    @Test func returnsNilWithoutTable() {
        #expect(ScorecardParser.parse([OCRToken(text: "Hello", minX: 0, maxX: 0.2, midY: 0.5, height: 0.03)]) == nil)
    }
}
