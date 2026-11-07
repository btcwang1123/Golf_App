import AppIntents
import Foundation
import GolfKit

/// Lets Shortcuts / the Ultra Action button reach the round store.
@MainActor
final class WatchIntentBridge {
    static let shared = WatchIntentBridge()
    weak var store: WatchRoundStore?
}

enum WatchIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveRound
    var localizedStringResource: LocalizedStringResource { "目前沒有進行中的回合。" }
}

@MainActor
private func store() throws -> WatchRoundStore {
    guard let s = WatchIntentBridge.shared.store, s.active != nil else { throw WatchIntentError.noActiveRound }
    return s
}

struct WatchAddStrokeIntent: AppIntent {
    static let title: LocalizedStringResource = "記一桿"
    static let description = IntentDescription("在目前球洞記一桿；可指定給 Apple Watch Ultra 動作按鈕。")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = try store()
        s.addStroke(s.isOnGreen ? .putt : .manual)
        return .result(dialog: "第 \(s.currentHoleNumber) 洞 \(s.currentHoleState.total) 桿")
    }
}

struct WatchAddPuttIntent: AppIntent {
    static let title: LocalizedStringResource = "記一桿推桿"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = try store()
        s.addStroke(.putt)
        return .result(dialog: "第 \(s.currentHoleNumber) 洞 \(s.currentHoleState.total) 桿")
    }
}

struct WatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WatchAddStrokeIntent(), phrases: ["用\(.applicationName)記一桿", "\(.applicationName)記一桿"],
                    shortTitle: "記一桿", systemImageName: "plus.circle")
        AppShortcut(intent: WatchAddPuttIntent(), phrases: ["用\(.applicationName)記推桿", "\(.applicationName)推桿"],
                    shortTitle: "記推桿", systemImageName: "circle.dotted")
    }
}
