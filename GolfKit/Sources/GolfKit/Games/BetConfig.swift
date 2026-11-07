import Foundation

/// Money games played alongside the scoring format. Amounts are whole currency units (e.g. NT$).
public struct BetConfig: Sendable, Codable, Equatable, Hashable {
    public enum Game: String, Sendable, Codable, Equatable, Hashable, CaseIterable, Identifiable {
        /// Every stroke of difference between two players is worth the stake.
        case perStroke
        /// Front nine, back nine and overall, each a separate bet between every pair.
        case nassau
        /// Unique lowest score on a hole wins a skin from everyone; ties carry over.
        case skins
        /// Each birdie (eagle = 2, ...) collects the stake from every other player.
        case birdie
        /// Two vs two; the pair's scores form a two-digit number, the difference is paid.
        case vegas
        /// Rotating wolf picks a partner or plays alone (double stakes).
        case wolf

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .perStroke: "比桿差"
            case .nassau: "Nassau"
            case .skins: "Skins"
            case .birdie: "博蒂獎金"
            case .vegas: "拉斯維加斯"
            case .wolf: "鬥地主"
            }
        }

        public var explanation: String {
            switch self {
            case .perStroke: "兩兩比總桿，每差一桿付一注。"
            case .nassau: "前九、後九、全場各一注，兩兩比桿。"
            case .skins: "該洞唯一最低者向每人收一注，平手累積到下一洞。"
            case .birdie: "博蒂向每人收一注，老鷹兩注，以此類推。"
            case .vegas: "兩人一隊，低分在前組成兩位數（博蒂時對手數字反轉），差多少付多少注。"
            case .wolf: "每洞輪一位地主，可選一位隊友或單挑（雙倍），最佳球比輸贏。"
            }
        }

        public func allows(playerCount: Int) -> Bool {
            switch self {
            case .vegas: playerCount == 4
            case .wolf: (3...4).contains(playerCount)
            default: playerCount >= 2
            }
        }
    }

    public struct Stake: Sendable, Codable, Equatable, Hashable {
        public var game: Game
        public var amount: Int

        public init(game: Game, amount: Int) {
            self.game = game
            self.amount = amount
        }
    }

    public var stakes: [Stake]
    /// Use net scores (strokes relative to the lowest handicap in the group).
    public var useHandicap: Bool
    /// Two player ids forming team A for Vegas; others are team B. Empty = first two players.
    public var vegasTeam: [UUID]

    public init(stakes: [Stake] = [], useHandicap: Bool = false, vegasTeam: [UUID] = []) {
        self.stakes = stakes
        self.useHandicap = useHandicap
        self.vegasTeam = vegasTeam
    }

    public var isEmpty: Bool { stakes.allSatisfy { $0.amount <= 0 } }

    public func amount(for game: Game) -> Int { stakes.first { $0.game == game }?.amount ?? 0 }

    public mutating func setAmount(_ amount: Int, for game: Game) {
        stakes.removeAll { $0.game == game }
        if amount > 0 { stakes.append(Stake(game: game, amount: amount)) }
        stakes.sort { Game.allCases.firstIndex(of: $0.game) ?? 0 < Game.allCases.firstIndex(of: $1.game) ?? 0 }
    }

    /// Games that are enabled and valid for this many players.
    public func activeGames(playerCount: Int) -> [Stake] {
        stakes.filter { $0.amount > 0 && $0.game.allows(playerCount: playerCount) }
    }
}

/// Wolf decision on one hole.
public struct WolfPick: Sendable, Codable, Equatable, Hashable {
    /// nil = lone wolf.
    public var partnerId: UUID?

    public init(partnerId: UUID?) {
        self.partnerId = partnerId
    }

    public var isLoneWolf: Bool { partnerId == nil }
}
