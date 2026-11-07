import Foundation
import GolfKit

/// Holds `AppSettings` on the watch, persisted in UserDefaults.
@MainActor @Observable
final class WatchSettingsService {
    private static let key = "app_settings"

    private(set) var settings: AppSettings
    /// Fired for every change (local or from the phone).
    @ObservationIgnored var onChange: (@MainActor (AppSettings) -> Void)?
    /// Fired only for edits made on the watch (to send back to the phone).
    @ObservationIgnored var onLocalEdit: (@MainActor (AppSettings) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    /// Applies settings received from the iPhone.
    func apply(_ new: AppSettings) {
        guard new != settings else { return }
        settings = new
        persist()
        onChange?(new)
    }

    /// Applies a local edit and reports it for sending to the phone.
    func edit(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        guard copy != settings else { return }
        settings = copy
        persist()
        onChange?(copy)
        onLocalEdit?(copy)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
