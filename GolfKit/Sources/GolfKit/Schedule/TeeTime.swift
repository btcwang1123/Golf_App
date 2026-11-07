import Foundation

/// A planned round the user wants to be reminded about.
public struct TeeTime: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var courseId: String
    public var courseName: String
    /// Course location for the forecast.
    public var center: GeoPoint?
    public var date: Date
    /// Minutes before tee time for the "leave now" reminder.
    public var reminderMinutes: Int
    /// Send a forecast reminder the evening before.
    public var eveningBefore: Bool

    public init(id: UUID = UUID(), courseId: String, courseName: String, center: GeoPoint? = nil, date: Date,
                reminderMinutes: Int = 90, eveningBefore: Bool = true) {
        self.id = id
        self.center = center
        self.courseId = courseId
        self.courseName = courseName
        self.date = date
        self.reminderMinutes = reminderMinutes
        self.eveningBefore = eveningBefore
    }

    public static let eveningHour = 20

    /// When the reminders fire; past dates are dropped.
    public func reminderDates(now: Date = Date(), calendar: Calendar = .current) -> (evening: Date?, before: Date?) {
        var evening: Date?
        if eveningBefore, let prev = calendar.date(byAdding: .day, value: -1, to: date),
           let at = calendar.date(bySettingHour: Self.eveningHour, minute: 0, second: 0, of: prev), at > now {
            evening = at
        }
        let before = date.addingTimeInterval(-Double(reminderMinutes) * 60)
        return (evening, before > now ? before : nil)
    }

    /// Upcoming tee times, soonest first (keeps ones within the last 6 hours so a round about to start still shows).
    public static func upcoming(_ all: [TeeTime], now: Date = Date()) -> [TeeTime] {
        all.filter { $0.date > now.addingTimeInterval(-6 * 3600) }.sorted { $0.date < $1.date }
    }
}
