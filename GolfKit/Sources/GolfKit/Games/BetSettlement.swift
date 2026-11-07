import Foundation

/// Who owes whom after a round's money games.
public struct BetSettlement: Sendable, Equatable {
    public struct Transfer: Sendable, Equatable, Hashable {
        public var from: UUID
        public var to: UUID
        public var amount: Int

        public init(from: UUID, to: UUID, amount: Int) {
            self.from = from
            self.to = to
            self.amount = amount
        }
    }

    public struct GameResult: Sendable, Equatable {
        public var game: BetConfig.Game
        public var stake: Int
        /// Net winnings per player (sum is zero).
        public var net: [UUID: Int]
        /// Short human summary, e.g. "3 skins · 累積 1".
        public var notes: [UUID: String]
    }

    public var games: [GameResult]
    /// Net winnings per player over all games.
    public var totals: [UUID: Int]
    /// Minimal list of payments that settles `totals`.
    public var transfers: [Transfer]

    public var isEmpty: Bool { games.isEmpty }

    // MARK: Compute

    public static func compute(state: RoundState, course: Course?) -> BetSettlement {
        guard let config = state.bets else { return BetSettlement(games: [], totals: [:], transfers: []) }
        let players = state.players
        let ctx = Context(state: state, course: course, useHandicap: config.useHandicap)
        var games: [GameResult] = []
        for stake in config.activeGames(playerCount: players.count) {
            var ledger = Ledger(players: players.map(\.id))
            var notes: [UUID: String] = [:]
            switch stake.game {
            case .perStroke: perStroke(ctx, stake.amount, &ledger, &notes)
            case .nassau: nassau(ctx, stake.amount, &ledger, &notes)
            case .skins: skins(ctx, stake.amount, &ledger, &notes)
            case .birdie: birdies(ctx, stake.amount, &ledger, &notes)
            case .vegas: vegas(ctx, config.vegasTeam, stake.amount, &ledger, &notes)
            case .wolf: wolf(ctx, stake.amount, &ledger, &notes)
            }
            games.append(GameResult(game: stake.game, stake: stake.amount, net: ledger.net, notes: notes))
        }
        var totals: [UUID: Int] = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        for g in games { for (id, v) in g.net { totals[id, default: 0] += v } }
        return BetSettlement(games: games, totals: totals, transfers: minimalTransfers(totals))
    }

    /// Greedy: largest debtor pays largest creditor until everyone is square.
    public static func minimalTransfers(_ totals: [UUID: Int]) -> [Transfer] {
        var debtors = totals.filter { $0.value < 0 }.map { ($0.key, -$0.value) }
        var creditors = totals.filter { $0.value > 0 }.map { ($0.key, $0.value) }
        func sort(_ a: inout [(UUID, Int)]) { a.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.uuidString < $1.0.uuidString } }
        var out: [Transfer] = []
        sort(&debtors); sort(&creditors)
        while let d = debtors.first, let c = creditors.first {
            let pay = min(d.1, c.1)
            out.append(Transfer(from: d.0, to: c.0, amount: pay))
            debtors[0].1 -= pay
            creditors[0].1 -= pay
            debtors.removeAll { $0.1 == 0 }
            creditors.removeAll { $0.1 == 0 }
            sort(&debtors); sort(&creditors)
        }
        return out
    }

    // MARK: Helpers

    struct Ledger {
        var net: [UUID: Int]
        init(players: [UUID]) { net = Dictionary(uniqueKeysWithValues: players.map { ($0, 0) }) }
        mutating func pay(_ from: UUID, _ to: UUID, _ amount: Int) {
            guard amount != 0, from != to else { return }
            net[from, default: 0] -= amount
            net[to, default: 0] += amount
        }
    }

    struct Context {
        let players: [Player]
        let gross: [UUID: [Int: Int]]
        let net: [UUID: [Int: Int]]
        let pars: [Int: Int]
        let holeCount: Int
        let wolfPicks: [Int: WolfPick]

        init(state: RoundState, course: Course?, useHandicap: Bool) {
            players = state.players
            let count = max(course?.holes.count ?? 0, state.holes.count, 1)
            holeCount = count
            let lowest = state.players.compactMap(\.handicap).min() ?? 0
            var g: [UUID: [Int: Int]] = [:], n: [UUID: [Int: Int]] = [:]
            for p in state.players {
                let scores = state.scores(for: p.id)
                let allowance = useHandicap ? max(0, (p.handicap ?? lowest) - lowest) : 0
                for (hole, s) in scores {
                    g[p.id, default: [:]][hole] = s.strokes
                    let received = HandicapAllocator.strokes(
                        handicap: allowance, holeHandicap: course?.hole(hole)?.handicap,
                        holeCount: count, holeNumber: hole)
                    n[p.id, default: [:]][hole] = s.strokes - received
                }
            }
            gross = g
            net = n
            var pars: [Int: Int] = [:]
            for h in state.holes { if let p = h.par ?? course?.hole(h.number)?.par { pars[h.number] = p } }
            for h in course?.holes ?? [] where pars[h.number] == nil { if let p = h.par { pars[h.number] = p } }
            self.pars = pars
            wolfPicks = state.wolfPicks
        }

        /// Holes where every listed player has a score.
        func commonHoles(_ ids: [UUID], in range: ClosedRange<Int>? = nil) -> [Int] {
            guard let first = ids.first else { return [] }
            return (net[first] ?? [:]).keys
                .filter { h in ids.allSatisfy { net[$0]?[h] != nil } && (range?.contains(h) ?? true) }
                .sorted()
        }

        func pairs() -> [(Player, Player)] {
            var out: [(Player, Player)] = []
            for i in players.indices { for j in players.indices where j > i { out.append((players[i], players[j])) } }
            return out
        }
    }

    static func perStroke(_ c: Context, _ stake: Int, _ l: inout Ledger, _ notes: inout [UUID: String]) {
        for (a, b) in c.pairs() {
            let holes = c.commonHoles([a.id, b.id])
            let sa = holes.reduce(0) { $0 + (c.net[a.id]?[$1] ?? 0) }
            let sb = holes.reduce(0) { $0 + (c.net[b.id]?[$1] ?? 0) }
            if sa < sb { l.pay(b.id, a.id, (sb - sa) * stake) } else if sb < sa { l.pay(a.id, b.id, (sa - sb) * stake) }
        }
        for p in c.players {
            let holes = (c.net[p.id] ?? [:]).values.reduce(0, +)
            notes[p.id] = "\(holes) 桿"
        }
    }

    static func nassau(_ c: Context, _ stake: Int, _ l: inout Ledger, _ notes: inout [UUID: String]) {
        let segments: [ClosedRange<Int>] = c.holeCount > 9 ? [1...9, 10...c.holeCount, 1...c.holeCount] : [1...c.holeCount]
        var wins: [UUID: Int] = [:]
        for (a, b) in c.pairs() {
            for seg in segments {
                let holes = c.commonHoles([a.id, b.id], in: seg)
                guard !holes.isEmpty else { continue }
                let sa = holes.reduce(0) { $0 + (c.net[a.id]?[$1] ?? 0) }
                let sb = holes.reduce(0) { $0 + (c.net[b.id]?[$1] ?? 0) }
                if sa < sb { l.pay(b.id, a.id, stake); wins[a.id, default: 0] += 1 }
                else if sb < sa { l.pay(a.id, b.id, stake); wins[b.id, default: 0] += 1 }
            }
        }
        for p in c.players { notes[p.id] = "贏 \(wins[p.id] ?? 0) 注" }
    }

    static func skins(_ c: Context, _ stake: Int, _ l: inout Ledger, _ notes: inout [UUID: String]) {
        let ids = c.players.map(\.id)
        var carry = 0
        var won: [UUID: Int] = [:]
        for h in c.commonHoles(ids) {
            let scores = ids.map { ($0, c.net[$0]?[h] ?? 0) }
            guard let best = scores.map(\.1).min() else { continue }
            let winners = scores.filter { $0.1 == best }
            if winners.count == 1 {
                let w = winners[0].0
                let count = 1 + carry
                won[w, default: 0] += count
                for id in ids where id != w { l.pay(id, w, count * stake) }
                carry = 0
            } else {
                carry += 1
            }
        }
        for p in c.players {
            let k = won[p.id] ?? 0
            notes[p.id] = carry > 0 ? "\(k) skins · 累積 \(carry)" : "\(k) skins"
        }
    }

    static func birdies(_ c: Context, _ stake: Int, _ l: inout Ledger, _ notes: inout [UUID: String]) {
        let ids = c.players.map(\.id)
        for p in c.players {
            var points = 0
            for (h, strokes) in c.gross[p.id] ?? [:] {
                guard let par = c.pars[h] else { continue }
                points += max(0, par - strokes)
            }
            for other in ids where other != p.id { l.pay(other, p.id, points * stake) }
            notes[p.id] = "\(points) 點"
        }
    }

    /// Two-digit team number, low score first. `flipped` puts the high score first.
    public static func vegasNumber(_ a: Int, _ b: Int, flipped: Bool) -> Int {
        let lo = min(a, b), hi = max(a, b)
        let first = flipped ? hi : lo, second = flipped ? lo : hi
        return Int("\(first)\(second)") ?? (first * 10 + second)
    }

    static func vegas(_ c: Context, _ team: [UUID], _ stake: Int, _ l: inout Ledger, _ notes: inout [UUID: String]) {
        let ids = c.players.map(\.id)
        let teamA = team.count == 2 && team.allSatisfy(ids.contains) ? team : Array(ids.prefix(2))
        let teamB = ids.filter { !teamA.contains($0) }
        guard teamA.count == 2, teamB.count == 2 else { return }
        var pointsA = 0
        for h in c.commonHoles(ids) {
            let a = teamA.map { c.net[$0]?[h] ?? 0 }, b = teamB.map { c.net[$0]?[h] ?? 0 }
            let par = c.pars[h]
            let aBirdie = par.map { p in a.contains { $0 < p } } ?? false
            let bBirdie = par.map { p in b.contains { $0 < p } } ?? false
            let na = vegasNumber(a[0], a[1], flipped: bBirdie && !aBirdie)
            let nb = vegasNumber(b[0], b[1], flipped: aBirdie && !bBirdie)
            pointsA += nb - na
        }
        // Each loser pays one winner: every player moves points × stake.
        if pointsA != 0 {
            let (winners, losers) = pointsA > 0 ? (teamA, teamB) : (teamB, teamA)
            let amount = abs(pointsA) * stake
            for (w, lo) in zip(winners, losers) { l.pay(lo, w, amount) }
        }
        for id in teamA { notes[id] = pointsA >= 0 ? "+\(pointsA) 點" : "\(pointsA) 點" }
        for id in teamB { notes[id] = pointsA <= 0 ? "+\(-pointsA) 點" : "\(-pointsA) 點" }
    }

    /// Wolf of a hole: players rotate in order starting at hole 1.
    public static func wolf(on hole: Int, players: [Player]) -> Player? {
        guard !players.isEmpty, hole >= 1 else { return nil }
        return players[(hole - 1) % players.count]
    }

    static func wolf(_ c: Context, _ stake: Int, _ l: inout Ledger, _ notes: inout [UUID: String]) {
        let ids = c.players.map(\.id)
        var holesWon: [UUID: Int] = [:]
        for h in c.commonHoles(ids) {
            guard let pick = c.wolfPicks[h], let wolf = wolf(on: h, players: c.players) else { continue }
            let wolfTeam = [wolf.id] + (pick.partnerId.map { [$0] } ?? []).filter { ids.contains($0) && $0 != wolf.id }
            let others = ids.filter { !wolfTeam.contains($0) }
            guard !others.isEmpty else { continue }
            let best = { (team: [UUID]) in team.compactMap { c.net[$0]?[h] }.min() ?? Int.max }
            let bw = best(wolfTeam), bo = best(others)
            guard bw != bo else { continue }
            let multiplier = wolfTeam.count == 1 ? 2 : 1
            let (winners, losers) = bw < bo ? (wolfTeam, others) : (others, wolfTeam)
            for w in winners { holesWon[w, default: 0] += 1 }
            // Every loser pays every winner, so a lone wolf collects from (or pays) everyone.
            for lo in losers { for w in winners { l.pay(lo, w, stake * multiplier) } }
        }
        for p in c.players { notes[p.id] = "贏 \(holesWon[p.id] ?? 0) 洞" }
    }
}
