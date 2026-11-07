import Foundation

/// Data the home-screen widget shows; written by the app into the shared app group.
public struct HomeWidgetSnapshot: Sendable, Codable, Equatable {
    public struct LastRound: Sendable, Codable, Equatable {
        public var courseName: String
        public var date: Date
        public var strokes: Int
        public var toPar: Int?
        public var holes: Int

        public init(courseName: String, date: Date, strokes: Int, toPar: Int?, holes: Int) {
            self.courseName = courseName
            self.date = date
            self.strokes = strokes
            self.toPar = toPar
            self.holes = holes
        }
    }

    public struct NextTeeTime: Sendable, Codable, Equatable {
        public var courseName: String
        public var date: Date

        public init(courseName: String, date: Date) {
            self.courseName = courseName
            self.date = date
        }
    }

    public var lastRound: LastRound?
    /// Average to par per 18 over the last 10 rounds.
    public var averageToPar: Double?
    /// To par per 18 of recent rounds, oldest first (max 10).
    public var trend: [Double]
    public var roundsThisYear: Int
    public var achievements: Int
    public var nextTeeTime: NextTeeTime?
    public var updatedAt: Date

    public init(lastRound: LastRound? = nil, averageToPar: Double? = nil, trend: [Double] = [], roundsThisYear: Int = 0,
                achievements: Int = 0, nextTeeTime: NextTeeTime? = nil, updatedAt: Date = Date()) {
        self.lastRound = lastRound
        self.averageToPar = averageToPar
        self.trend = trend
        self.roundsThisYear = roundsThisYear
        self.achievements = achievements
        self.nextTeeTime = nextTeeTime
        self.updatedAt = updatedAt
    }

    public static let appGroup = "group.com.bobby.golfapp"
    public static let defaultsKey = "homeWidgetSnapshot"

    public static let placeholder = HomeWidgetSnapshot(
        lastRound: LastRound(courseName: "台北高爾夫俱樂部", date: Date(timeIntervalSince1970: 1_760_000_000),
                             strokes: 88, toPar: 16, holes: 18),
        averageToPar: 17.4, trend: [21, 19, 20, 18, 17, 16, 18, 15], roundsThisYear: 14, achievements: 9)

    public static func load(from defaults: UserDefaults?) -> HomeWidgetSnapshot? {
        guard let data = defaults?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(HomeWidgetSnapshot.self, from: data)
    }

    public func save(to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.defaultsKey)
    }
}
