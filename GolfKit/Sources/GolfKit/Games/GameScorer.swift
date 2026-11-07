import Foundation

public struct Standing: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var playerId: UUID
    /// Primary ranking value (net to par for stroke play, points otherwise).
    public var value: Int
    public var rank: Int
    public var gross: Int
    public var net: Int
    public var holesPlayed: Int
    public var detail: String

    public var id: UUID { playerId }

    public init(playerId: UUID, value: Int, rank: Int, gross: Int, net: Int, holesPlayed: Int, detail: String) {
        self.playerId = playerId
        self.value = value
        self.rank = rank
        self.gross = gross
        self.net = net
        self.holesPlayed = holesPlayed
        self.detail = detail
    }
}

public enum GameScorer {
    /// Stableford points for net score relative to par: double bogey+ 0, bogey 1, par 2, birdie 3, eagle 4 (albatross 5).
    public static func stablefordPoints(net: Int, par: Int) -> Int {
        max(0, 2 + par - net)
    }

    public static func standings(state: RoundState, course: Course?) -> [Standing] {
        let players = state.players
        let holeCount = max(course?.holes.count ?? 0, state.holes.count, 1)
        let game = state.game
        let relative = game.kind == .match || game.kind == .skins
        let lowest = players.compactMap(\.handicap).min() ?? 0

        func allowance(_ p: Player) -> Int {
            guard game.useHandicap, let h = p.handicap else { return 0 }
            return relative ? max(0, h - lowest) : max(0, h)
        }
        func par(_ n: Int) -> Int? { state.hole(n)?.par ?? course?.hole(n)?.par }
        func received(_ p: Player, _ n: Int) -> Int {
            HandicapAllocator.strokes(
                handicap: allowance(p), holeHandicap: course?.hole(n)?.handicap,
                holeCount: holeCount, holeNumber: n)
        }

        let scores = Dictionary(uniqueKeysWithValues: players.map { ($0.id, state.scores(for: $0.id)) })
        func net(_ p: Player, _ n: Int) -> Int? {
            scores[p.id]?[n].map { $0.strokes - received(p, n) }
        }

        var rows: [(player: Player, value: Int, gross: Int, net: Int, played: Int, detail: String)] = []
        let higherIsBetter: Bool

        switch game.kind {
        case .stroke:
            higherIsBetter = false
            for p in players {
                let s = scores[p.id] ?? [:]
                let gross = s.values.reduce(0) { $0 + $1.strokes }
                let netTotal = s.keys.reduce(0) { $0 + (net(p, $1) ?? 0) }
                let parSum = s.keys.compactMap(par).reduce(0, +)
                let toPar = netTotal - parSum
                let detail = game.useHandicap ? "總 \(gross) · 淨 \(netTotal)" : "總 \(gross)"
                rows.append((p, toPar, gross, netTotal, s.count, detail))
            }
        case .stableford:
            higherIsBetter = true
            for p in players {
                let s = scores[p.id] ?? [:]
                var pts = 0
                for n in s.keys { if let pr = par(n), let nt = net(p, n) { pts += stablefordPoints(net: nt, par: pr) } }
                let gross = s.values.reduce(0) { $0 + $1.strokes }
                let netTotal = s.keys.reduce(0) { $0 + (net(p, $1) ?? 0) }
                rows.append((p, pts, gross, netTotal, s.count, "\(pts) 分"))
            }
        case .skins:
            higherIsBetter = true
            var skins: [UUID: Int] = [:]
            var carry = 0
            let holes = Set(scores.values.flatMap(\.keys)).sorted()
            for n in holes {
                let nets = players.compactMap { p in net(p, n).map { (p.id, $0) } }
                guard nets.count == players.count, let best = nets.map(\.1).min() else { continue }
                let winners = nets.filter { $0.1 == best }
                if winners.count == 1 {
                    skins[winners[0].0, default: 0] += 1 + carry
                    carry = 0
                } else {
                    carry += 1
                }
            }
            for p in players {
                let s = scores[p.id] ?? [:]
                let gross = s.values.reduce(0) { $0 + $1.strokes }
                let netTotal = s.keys.reduce(0) { $0 + (net(p, $1) ?? 0) }
                let k = skins[p.id] ?? 0
                rows.append((p, k, gross, netTotal, s.count, carry > 0 ? "\(k) skins · 累積 \(carry)" : "\(k) skins"))
            }
        case .match:
            higherIsBetter = true
            guard players.count == 2 else {
                return standings(state: withGame(state, .init(kind: .stroke, useHandicap: game.useHandicap)), course: course)
            }
            let a = players[0], b = players[1]
            var up = 0, both = 0
            let holes = Set(scores.values.flatMap(\.keys)).sorted()
            for n in holes {
                guard let na = net(a, n), let nb = net(b, n) else { continue }
                both += 1
                if na < nb { up += 1 } else if nb < na { up -= 1 }
            }
            let remaining = max(0, holeCount - both)
            for (p, sign) in [(a, 1), (b, -1)] {
                let s = scores[p.id] ?? [:]
                let gross = s.values.reduce(0) { $0 + $1.strokes }
                let netTotal = s.keys.reduce(0) { $0 + (net(p, $1) ?? 0) }
                rows.append((p, up * sign, gross, netTotal, s.count, matchStatus(up: up * sign, remaining: remaining)))
            }
        }

        // Competition ranking (1, 1, 3).
        // Players without a score go last.
        let sorted = rows.sorted {
            if ($0.played > 0) != ($1.played > 0) { return $0.played > 0 }
            return higherIsBetter ? $0.value > $1.value : $0.value < $1.value
        }
        var out: [Standing] = []
        for (i, r) in sorted.enumerated() {
            let tie = i > 0 && sorted[i - 1].value == r.value && (sorted[i - 1].played > 0) == (r.played > 0)
            let rank = tie ? out[i - 1].rank : i + 1
            out.append(Standing(playerId: r.player.id, value: r.value, rank: rank, gross: r.gross, net: r.net,
                                holesPlayed: r.played, detail: r.detail))
        }
        return out
    }

    /// "AS", "2 UP", "2 DN", or "3&2" once the match is decided.
    public static func matchStatus(up: Int, remaining: Int) -> String {
        if up == 0 { return "AS" }
        if abs(up) > remaining {
            let s = remaining == 0 ? "\(abs(up)) UP" : "\(abs(up))&\(remaining)"
            return up > 0 ? s : "輸 \(s)"
        }
        return up > 0 ? "\(up) UP" : "\(-up) DN"
    }

    private static func withGame(_ s: RoundState, _ g: GameFormat) -> RoundState {
        var c = s
        c.game = g
        return c
    }
}
