import AppIntents
import Foundation
import GolfKit

enum RoundIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveRound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveRound: "目前沒有進行中的回合。"
        }
    }
}

@MainActor
private func activeStore() throws -> RoundStore {
    guard let store = IntentBridge.shared.roundStore, let round = store.active, !round.isEnded else {
        throw RoundIntentError.noActiveRound
    }
    return store
}

@MainActor
private func scoreLine(_ store: RoundStore) -> String {
    guard let r = store.active else { return "" }
    let hole = r.hole(r.currentHole)
    let toPar = r.toPar.map { $0 == 0 ? "E" : $0 > 0 ? "+\($0)" : "\($0)" } ?? "E"
    return String(localized: "第 \(r.currentHole) 洞 \(hole?.total ?? 0) 桿，總桿 \(r.totalStrokes)（\(toPar)）。")
}

struct AddSwingIntent: AppIntent {
    static let title: LocalizedStringResource = "記一桿"
    static let description = IntentDescription("在目前球洞記一桿揮桿。")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try activeStore()
        let hole = store.active?.currentHole ?? 1
        store.append(.stroke(hole: hole, type: .swing, location: IntentBridge.shared.location?.current, swing: nil))
        return .result(dialog: IntentDialog(stringLiteral: scoreLine(store)))
    }
}

struct AddPuttIntent: AppIntent {
    static let title: LocalizedStringResource = "記一桿推桿"
    static let description = IntentDescription("在目前球洞記一桿推桿。")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try activeStore()
        let hole = store.active?.currentHole ?? 1
        store.append(.stroke(hole: hole, type: .putt, location: IntentBridge.shared.location?.current, swing: nil))
        return .result(dialog: IntentDialog(stringLiteral: scoreLine(store)))
    }
}

struct AddPenaltyIntent: AppIntent {
    static let title: LocalizedStringResource = "記一桿罰桿"

    @Parameter(title: "原因")
    var reason: PenaltyReasonEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try activeStore()
        let hole = store.active?.currentHole ?? 1
        store.append(.penalty(hole: hole, count: 1, reason: reason?.reason))
        return .result(dialog: IntentDialog(stringLiteral: scoreLine(store)))
    }
}

struct SetHoleScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "設定這洞桿數"
    static let description = IntentDescription("把目前球洞的總桿數改成指定數字（不含罰桿）。")

    @Parameter(title: "桿數", inclusiveRange: (1, 15))
    var strokes: Int

    static var parameterSummary: some ParameterSummary { Summary("這洞 \(\.$strokes) 桿") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try activeStore()
        guard let round = store.active else { throw RoundIntentError.noActiveRound }
        let n = round.currentHole
        let shots = round.hole(n)?.shots ?? []
        if shots.count < strokes {
            store.append(Array(repeating: .stroke(hole: n, type: .manual, location: nil, swing: nil), count: strokes - shots.count))
        } else if shots.count > strokes {
            store.append(shots.suffix(shots.count - strokes).map { .void(strokeId: $0.id) })
        }
        return .result(dialog: IntentDialog(stringLiteral: scoreLine(store)))
    }
}

struct NextHoleIntent: AppIntent {
    static let title: LocalizedStringResource = "下一洞"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try activeStore()
        let next = (store.active?.currentHole ?? 0) + 1
        let max = store.activeCourse?.holes.map(\.number).max() ?? 18
        if next <= max { store.append(.goToHole(next)) }
        return .result(dialog: IntentDialog(stringLiteral: scoreLine(store)))
    }
}

struct CurrentScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "目前成績"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try activeStore()
        var line = scoreLine(store)
        if let r = store.active, let hole = store.activeCourse?.hole(r.currentHole),
           let here = IntentBridge.shared.location?.current,
           let d = hole.distancesMeters(from: here, pin: r.pin(for: r.currentHole)) {
            let text = IntentBridge.shared.settings?.settings.format(meters: d.center) ?? "\(Int(d.center.rounded())) m"
            line += String(localized: " 到果嶺中心 \(text)。")
        }
        return .result(dialog: IntentDialog(stringLiteral: line))
    }
}

struct PenaltyReasonEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "罰桿原因"
    static let defaultQuery = PenaltyReasonQuery()

    var id: String
    var reason: PenaltyReason { PenaltyReason(rawValue: id) ?? .other }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(reason.title)") }
}

struct PenaltyReasonQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PenaltyReasonEntity] {
        identifiers.map { PenaltyReasonEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [PenaltyReasonEntity] {
        PenaltyReason.allCases.map { PenaltyReasonEntity(id: $0.rawValue) }
    }
}

struct GolfShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddSwingIntent(), phrases: ["用\(.applicationName)記一桿", "\(.applicationName)記一桿", "\(.applicationName) add a stroke"],
                    shortTitle: "記一桿", systemImageName: "plus.circle")
        AppShortcut(intent: AddPuttIntent(), phrases: ["用\(.applicationName)記推桿", "\(.applicationName)推桿", "\(.applicationName) add a putt"],
                    shortTitle: "記推桿", systemImageName: "circle.dotted")
        AppShortcut(intent: AddPenaltyIntent(), phrases: ["用\(.applicationName)記罰桿", "\(.applicationName)罰桿"],
                    shortTitle: "記罰桿", systemImageName: "exclamationmark.triangle")
        AppShortcut(intent: SetHoleScoreIntent(), phrases: ["用\(.applicationName)設定這洞桿數", "\(.applicationName)這洞幾桿"],
                    shortTitle: "這洞桿數", systemImageName: "number")
        AppShortcut(intent: NextHoleIntent(), phrases: ["\(.applicationName)下一洞", "\(.applicationName) next hole"],
                    shortTitle: "下一洞", systemImageName: "chevron.right.circle")
        AppShortcut(intent: CurrentScoreIntent(), phrases: ["\(.applicationName)目前成績", "\(.applicationName)我打幾桿"],
                    shortTitle: "目前成績", systemImageName: "list.number")
    }
}
