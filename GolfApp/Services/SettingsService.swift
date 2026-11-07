import Foundation
import GolfKit
import Observation

@MainActor @Observable
final class SettingsService {
    private static let key = "appSettings.v1"

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            Haptics.isEnabled = settings.hapticsOn
            persist()
            if !applyingRemote { onChange?(settings) }
        }
    }

    @ObservationIgnored var onChange: ((AppSettings) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var applyingRemote = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
        Haptics.isEnabled = settings.hapticsOn
    }

    /// Applies settings received from the Watch without echoing them back.
    func applyRemote(_ new: AppSettings) {
        applyingRemote = true
        settings = new
        applyingRemote = false
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
