import Foundation

/// "Year in golf" style summary of a month or a year.
public struct PeriodRecap: Sendable, Equatable {
    public enum Period: Sendable, Hashable, Comparable, Identifiable {
        case year(Int)
        case month(year: Int, month: Int)

        public var id: String {
            switch self {
            case .year(let y): "\(y)"
            case .month(let y, let m): "\(y)-\(m)"
            }
        }

        public var year: Int {
            switch self {
            case .year(let y), .month(let y, _): y
            }
        }

        public func contains(_ date: Date, calendar: Calendar) -> Bool {
            let c = calendar.dateComponents([.year, .month], from: date)
            switch self {
            case .year(let y): return c.year == y
            case .month(let y, let m): return c.year == y && c.month == m
            }
        }

        private var sortKey: Int {
            switch self {
            case .year(let y): y * 100 + 99
            case .month(let y, let m): y * 100 + m
            }
        }

        public static func < (a: Period, b: Period) -> Bool { a.sortKey < b.sortKey }
    }

    public struct BestRound: Sendable, Equatable {
        public var roundId: UUID
        public var courseId: String?
        public var date: Date
        public var strokes: Int
        public var toPar: Int?
        public var holes: Int
    }

    public var period: Period
    public var roundCount: Int
    public var holesPlayed: Int
    public var totalStrokes: Int
    public var best18: BestRound?
    public var best9: BestRound?
    public var averageScore18: Double?
    public var eagles: Int
    public var birdies: Int
    public var pars: Int
    public var holeInOnes: Int
    /// Most played course and how many times.
    public var favoriteCourse: (id: String, rounds: Int)?
    public var coursesPlayed: Int
    public var longestShot: (meters: Double, club: Club?)?
    /// Most used club (putter excluded) and its shot count.
    public var favoriteClub: (club: Club, shots: Int)?
    public var puttsPerHole: Double?
    public var hoursPlayed: Double
    /// Rough walk estimate from shot to shot.
    public var metersWalked: Double
    /// Average to-par per 18 holes: first half of the period minus second half (positive = improved).
    public var improvement: Double?
    /// For a year: the month with the most rounds.
    public var busiestMonth: (month: Int, rounds: Int)?
    public var unlocks: [AchievementUnlock]

    public static func == (a: PeriodRecap, b: PeriodRecap) -> Bool {
        a.period == b.period && a.roundCount == b.roundCount && a.totalStrokes == b.totalStrokes
            && a.best18 == b.best18 && a.best9 == b.best9 && a.birdies == b.birdies && a.eagles == b.eagles
            && a.unlocks == b.unlocks && a.favoriteCourse?.id == b.favoriteCourse?.id
    }

    /// Periods that have at least one finished round, newest first; years before their months.
    public static func availablePeriods(rounds: [RoundState], calendar: Calendar = .current) -> [Period] {
        var set = Set<Period>()
        for r in rounds where r.totalStrokes > 0 {
            guard let d = r.startedAt else { continue }
            let c = calendar.dateComponents([.year, .month], from: d)
            guard let y = c.year, let m = c.month else { continue }
            set.insert(.year(y))
            set.insert(.month(year: y, month: m))
        }
        return set.sorted(by: >)
    }

    public static func make(period: Period, rounds: [RoundState], unlocks: [AchievementUnlock] = [],
                            calendar: Calendar = .current) -> PeriodRecap {
        let picked = rounds
            .filter { r in r.totalStrokes > 0 && r.startedAt.map { period.contains($0, calendar: calendar) } == true }
            .sorted { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }

        var holes = 0, strokes = 0, eagles = 0, birdies = 0, pars = 0, aces = 0, putts = 0, puttHoles = 0
        var courses: [String: Int] = [:]
        var clubs: [Club: Int] = [:]
        var longest: (Double, Club?)?
        var seconds = 0.0, walked = 0.0
        var best18: BestRound?, best9: BestRound?
        var scores18: [Int] = []
        var months: [Int: Int] = [:]
        var perRoundToPar18: [Double] = []

        for r in picked {
            let played = r.holes.filter { $0.total > 0 }
            holes += played.count
            strokes += r.totalStrokes
            if let c = r.courseId { courses[c, default: 0] += 1 }
            if let d = r.startedAt, let m = calendar.dateComponents([.month], from: d).month { months[m, default: 0] += 1 }
            if let e = r.elapsed(), r.endedAt != nil, e < 12 * 3600 { seconds += e }
            for h in played {
                if let par = h.par {
                    let d = h.total - par
                    if d <= -2 { eagles += 1 } else if d == -1 { birdies += 1 } else if d == 0 { pars += 1 }
                    if h.total == 1 { aces += 1 }
                }
                if h.putts > 0 || !r.isManualEntry { putts += h.putts; puttHoles += 1 }
                let located = h.shots.compactMap(\.location)
                for (a, b) in zip(located, located.dropFirst()) { walked += Geo.distance(a, b) }
                for s in h.shots where s.type != .putt {
                    if let c = s.club, c != .putter { clubs[c, default: 0] += 1 }
                    if let d = s.distanceToNext, ClubProfile.validRange.contains(d), d > (longest?.0 ?? 0) {
                        longest = (d, s.club)
                    }
                }
            }
            let b = BestRound(roundId: r.roundId, courseId: r.courseId, date: r.startedAt ?? .distantPast,
                              strokes: r.totalStrokes, toPar: r.toPar, holes: played.count)
            if played.count >= 18 {
                scores18.append(r.totalStrokes)
                if best18.map({ b.strokes < $0.strokes }) ?? true { best18 = b }
            } else if played.count <= 9 {
                if best9.map({ b.strokes < $0.strokes }) ?? true { best9 = b }
            }
            if let tp = r.toPar, !played.isEmpty { perRoundToPar18.append(Double(tp) * 18 / Double(played.count)) }
        }

        var improvement: Double?
        if perRoundToPar18.count >= 4 {
            let half = perRoundToPar18.count / 2
            let first = perRoundToPar18.prefix(half), second = perRoundToPar18.suffix(perRoundToPar18.count - half)
            improvement = first.reduce(0, +) / Double(first.count) - second.reduce(0, +) / Double(second.count)
        }
        let fav = courses.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }
        let favClub = clubs.max { $0.value != $1.value ? $0.value < $1.value : $0.key.rawValue > $1.key.rawValue }
        var busiest: (Int, Int)?
        if case .year = period, let m = months.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }) {
            busiest = (m.key, m.value)
        }
        return PeriodRecap(
            period: period, roundCount: picked.count, holesPlayed: holes, totalStrokes: strokes,
            best18: best18, best9: best9,
            averageScore18: scores18.isEmpty ? nil : Double(scores18.reduce(0, +)) / Double(scores18.count),
            eagles: eagles, birdies: birdies, pars: pars, holeInOnes: aces,
            favoriteCourse: fav.map { ($0.key, $0.value) }, coursesPlayed: courses.count,
            longestShot: longest.map { ($0.0, $0.1) }, favoriteClub: favClub.map { ($0.key, $0.value) },
            puttsPerHole: puttHoles > 0 ? Double(putts) / Double(puttHoles) : nil,
            hoursPlayed: seconds / 3600, metersWalked: walked, improvement: improvement,
            busiestMonth: busiest.map { ($0.0, $0.1) },
            unlocks: unlocks.filter { period.contains($0.date, calendar: calendar) })
    }
}
