import Foundation
import GolfKit
import Observation
import OSLog
import UserNotifications

/// Planned tee times with local reminders (forecast the evening before, "time to go" before tee off).
@MainActor @Observable
final class TeeTimeStore {
    private(set) var all: [TeeTime] = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "GolfApp", category: "TeeTime")
    @ObservationIgnored var onChange: (() -> Void)?

    static let key = "teeTimes.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let list = try? JSONDecoder().decode([TeeTime].self, from: data) {
            all = list
        }
    }

    var upcoming: [TeeTime] { TeeTime.upcoming(all) }

    func save(_ t: TeeTime, weather: WeatherService?) async {
        all.removeAll { $0.id == t.id }
        all.append(t)
        persist()
        await schedule(t, weather: weather)
    }

    func delete(_ t: TeeTime) {
        all.removeAll { $0.id == t.id }
        persist()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.ids(t))
    }

    /// Asks once; returns whether alerts are allowed.
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private func persist() {
        all = all.filter { $0.date > Date().addingTimeInterval(-7 * 86_400) }.sorted { $0.date < $1.date }
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: Self.key) }
        onChange?()
    }

    static func ids(_ t: TeeTime) -> [String] { ["tee-\(t.id)-evening", "tee-\(t.id)-before"] }

    private func schedule(_ t: TeeTime, weather: WeatherService?) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.ids(t))
        guard await requestAuthorization() else { return }
        let dates = t.reminderDates()
        let time = t.date.formatted(date: .omitted, time: .shortened)
        if let evening = dates.evening {
            var body = String(localized: "明天 \(time) 在 \(t.courseName) 開球。")
            if let weather, let center = t.center, let f = await weather.forecast(at: center, date: t.date) {
                body += " " + f.summary
            }
            await add(id: Self.ids(t)[0], title: String(localized: "明天要打球"), body: body, at: evening)
        }
        if let before = dates.before {
            await add(id: Self.ids(t)[1], title: String(localized: "準備出發"),
                      body: String(localized: "\(time) 在 \(t.courseName) 開球，記得帶 Apple Watch。"), at: before)
        }
    }

    private func add(id: String, title: String, body: String, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
            identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        do { try await UNUserNotificationCenter.current().add(request) } catch {
            log.error("schedule failed: \(error.localizedDescription)")
        }
    }
}
