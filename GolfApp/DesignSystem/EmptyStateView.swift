import SwiftUI

/// Friendly placeholder for empty lists and screens.
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    init(icon: String, title: LocalizedStringKey, message: LocalizedStringKey,
         actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.gold)
                .symbolEffect(.pulse, options: .repeating.speed(0.3))
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.display(24))
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .buttonStyle(GoldButtonStyle(compact: true))
                    .frame(maxWidth: 240)
                    .padding(.top, 6)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
