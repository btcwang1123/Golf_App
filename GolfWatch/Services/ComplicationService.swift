import Foundation
import GolfKit
import WidgetKit

/// Shares the round summary with the watch complication through the App Group and reloads it
/// only on strokes / hole changes to stay within the WidgetKit budget.
@MainActor
final class ComplicationService {
    private let defaults = UserDefaults(suiteName: ComplicationSnapshot.appGroup)
    private var last: ComplicationSnapshot?
    static let unitKey = "complicationUnit"

    func update(hole: Int, strokes: Int, distanceToPin: Double?, unit: AppSettings.DistanceUnit) {
        let snap = ComplicationSnapshot(hole: hole, strokes: strokes, distanceToPin: distanceToPin)
        if let last, last.hole == snap.hole, last.strokes == snap.strokes { return }
        last = snap
        defaults?.set(try? JSONEncoder().encode(snap), forKey: ComplicationSnapshot.defaultsKey)
        defaults?.set(unit == .meter ? "m" : "y", forKey: Self.unitKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clear() {
        last = nil
        defaults?.removeObject(forKey: ComplicationSnapshot.defaultsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
