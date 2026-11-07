import Foundation
import GolfKit

/// Lets App Intents (Siri / Shortcuts / Action button) reach the live services created by `GolfApp`.
@MainActor
final class IntentBridge {
    static let shared = IntentBridge()
    weak var roundStore: RoundStore?
    weak var location: LocationService?
    weak var settings: SettingsService?
}
