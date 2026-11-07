import UIKit

/// App-wide haptic vocabulary. Respects the user's haptics setting.
@MainActor
enum Haptics {
    enum Event {
        case stroke, birdie, holeChange, warning, selection
    }

    static var isEnabled = true

    static func play(_ e: Event) {
        guard isEnabled else { return }
        switch e {
        case .stroke: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .birdie: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .holeChange: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
