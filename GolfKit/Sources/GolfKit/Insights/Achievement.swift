import Foundation

/// Milestones unlocked from round history; all evaluated on device.
public enum Achievement: String, Sendable, Codable, Equatable, Hashable, CaseIterable, Identifiable {
    case firstRound, firstBirdie, firstEagle, holeInOne
    case break100, break90, break80, evenPar
    case parStreak3, parStreak5, birdieStreak2
    case noThreePutts, onePuttFive, noPenalties
    case firstGroupRound, earlyBird
    case rounds10, rounds25, rounds50, courses5, courses10

    public var id: String { rawValue }

    public enum Tier: Int, Sendable, Codable, Comparable {
        case bronze = 1, silver, gold
        public static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }
    }

    public var title: String {
        switch self {
        case .firstRound: "第一場"
        case .firstBirdie: "第一隻博蒂"
        case .firstEagle: "第一隻老鷹"
        case .holeInOne: "一桿進洞"
        case .break100: "破百"
        case .break90: "破 90"
        case .break80: "破 80"
        case .evenPar: "平標準桿"
        case .parStreak3: "連續 3 洞 Par"
        case .parStreak5: "連續 5 洞 Par"
        case .birdieStreak2: "連續博蒂"
        case .noThreePutts: "零三推"
        case .onePuttFive: "一推高手"
        case .noPenalties: "零罰桿"
        case .firstGroupRound: "揪團下場"
        case .earlyBird: "早鳥"
        case .rounds10: "10 場"
        case .rounds25: "25 場"
        case .rounds50: "50 場"
        case .courses5: "5 座球場"
        case .courses10: "10 座球場"
        }
    }

    public var detail: String {
        switch self {
        case .firstRound: "完成第一場回合。"
        case .firstBirdie: "單洞低於標準桿 1 桿。"
        case .firstEagle: "單洞低於標準桿 2 桿以上。"
        case .holeInOne: "Par 3 一桿進洞！"
        case .break100: "18 洞總桿低於 100。"
        case .break90: "18 洞總桿低於 90。"
        case .break80: "18 洞總桿低於 80。"
        case .evenPar: "18 洞打出標準桿或更好。"
        case .parStreak3: "同一場連續 3 洞 Par 或更好。"
        case .parStreak5: "同一場連續 5 洞 Par 或更好。"
        case .birdieStreak2: "同一場連續 2 洞博蒂以上。"
        case .noThreePutts: "18 洞沒有任何三推。"
        case .onePuttFive: "同一場 5 洞以上一推進洞。"
        case .noPenalties: "18 洞沒有任何罰桿。"
        case .firstGroupRound: "和朋友同組記分。"
        case .earlyBird: "早上 7 點前開球。"
        case .rounds10: "累積完成 10 場。"
        case .rounds25: "累積完成 25 場。"
        case .rounds50: "累積完成 50 場。"
        case .courses5: "打過 5 座不同球場。"
        case .courses10: "打過 10 座不同球場。"
        }
    }

    /// SF Symbol name.
    public var symbol: String {
        switch self {
        case .firstRound: "flag"
        case .firstBirdie: "bird"
        case .firstEagle: "bird.fill"
        case .holeInOne: "star.circle.fill"
        case .break100, .break90, .break80: "rosette"
        case .evenPar: "crown"
        case .parStreak3, .parStreak5: "flame"
        case .birdieStreak2: "sparkles"
        case .noThreePutts, .onePuttFive: "circle.circle"
        case .noPenalties: "checkmark.shield"
        case .firstGroupRound: "person.3"
        case .earlyBird: "sunrise"
        case .rounds10, .rounds25, .rounds50: "number.circle"
        case .courses5, .courses10: "map"
        }
    }

    public var tier: Tier {
        switch self {
        case .holeInOne, .break80, .evenPar, .firstEagle, .parStreak5, .rounds50, .courses10: .gold
        case .break90, .birdieStreak2, .noThreePutts, .onePuttFive, .noPenalties, .rounds25, .courses5: .silver
        default: .bronze
        }
    }
}

public struct AchievementUnlock: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var achievement: Achievement
    public var roundId: UUID
    public var date: Date

    public var id: Achievement { achievement }

    public init(achievement: Achievement, roundId: UUID, date: Date) {
        self.achievement = achievement
        self.roundId = roundId
        self.date = date
    }
}

public enum AchievementEngine {
    /// Achievements a single round earns on its own (no history needed).
    public static func earned(by r: RoundState, calendar: Calendar = .current) -> Set<Achievement> {
        var out: Set<Achievement> = []
        let played = r.holes.filter { $0.total > 0 }.sorted { $0.number < $1.number }
        guard !played.isEmpty else { return out }
        out.insert(.firstRound)
        let full = played.count >= 18
        for h in played {
            guard let par = h.par else { continue }
            if h.total <= par - 1 { out.insert(.firstBirdie) }
            if h.total <= par - 2 { out.insert(.firstEagle) }
            if h.total == 1 && par == 3 { out.insert(.holeInOne) }
        }
        if full {
            let total = r.totalStrokes
            if total < 100 { out.insert(.break100) }
            if total < 90 { out.insert(.break90) }
            if total < 80 { out.insert(.break80) }
            if let tp = r.toPar, tp <= 0, played.allSatisfy({ $0.par != nil }) { out.insert(.evenPar) }
            if played.allSatisfy({ $0.putts > 0 }), !played.contains(where: { $0.putts >= 3 }) { out.insert(.noThreePutts) }
            if !played.contains(where: { $0.penalties > 0 }) { out.insert(.noPenalties) }
        }
        if longestStreak(played, { $0 <= 0 }) >= 3 { out.insert(.parStreak3) }
        if longestStreak(played, { $0 <= 0 }) >= 5 { out.insert(.parStreak5) }
        if longestStreak(played, { $0 <= -1 }) >= 2 { out.insert(.birdieStreak2) }
        if played.filter({ $0.putts == 1 }).count >= 5 { out.insert(.onePuttFive) }
        if r.players.count > 1 { out.insert(.firstGroupRound) }
        if let s = r.startedAt, calendar.component(.hour, from: s) < 7 { out.insert(.earlyBird) }
        return out
    }

    /// Consecutive holes (by number, no gaps) whose to-par passes `test`.
    static func longestStreak(_ holes: [HoleState], _ test: (Int) -> Bool) -> Int {
        var best = 0, cur = 0, last: Int?
        for h in holes {
            guard let par = h.par else { cur = 0; last = nil; continue }
            let contiguous = last.map { h.number == $0 + 1 } ?? true
            if test(h.total - par) { cur = contiguous ? cur + 1 : 1 } else { cur = 0 }
            best = max(best, cur)
            last = h.number
        }
        return best
    }

    /// First unlock of every achievement over the history (any order in, oldest first out).
    public static func unlocks(rounds: [RoundState], calendar: Calendar = .current) -> [AchievementUnlock] {
        let sorted = rounds
            .filter { $0.totalStrokes > 0 }
            .sorted { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }
        var have: [Achievement: AchievementUnlock] = [:]
        var courses = Set<String>()
        for (i, r) in sorted.enumerated() {
            let date = r.startedAt ?? .distantPast
            var got = earned(by: r, calendar: calendar)
            let count = i + 1
            if count >= 10 { got.insert(.rounds10) }
            if count >= 25 { got.insert(.rounds25) }
            if count >= 50 { got.insert(.rounds50) }
            if let c = r.courseId { courses.insert(c) }
            if courses.count >= 5 { got.insert(.courses5) }
            if courses.count >= 10 { got.insert(.courses10) }
            for a in got where have[a] == nil {
                have[a] = AchievementUnlock(achievement: a, roundId: r.roundId, date: date)
            }
        }
        return have.values.sorted {
            $0.date != $1.date ? $0.date < $1.date
                : (Achievement.allCases.firstIndex(of: $0.achievement) ?? 0) < (Achievement.allCases.firstIndex(of: $1.achievement) ?? 0)
        }
    }

    /// Unlocks first earned in the given round.
    public static func newlyUnlocked(in roundId: UUID, rounds: [RoundState], calendar: Calendar = .current) -> [AchievementUnlock] {
        unlocks(rounds: rounds, calendar: calendar).filter { $0.roundId == roundId }
    }
}
