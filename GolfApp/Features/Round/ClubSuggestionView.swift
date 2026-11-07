import GolfKit
import SwiftUI

/// "建議 7 鐵（145 碼）" next to the distance badge.
struct ClubSuggestionView: View {
    let distance: Double?
    let profile: ClubProfile
    let headwind: Double?
    let settings: AppSettings

    var body: some View {
        Group {
            if !ClubAdvisor.hasEnoughData(profile) {
                label(icon: "lightbulb", text: String(localized: "記錄球桿以啟用建議"), dim: true)
            } else if let d = distance, d > StrokesGained.shortGameMeters,
                      let s = ClubAdvisor.suggest(distance: d, profile: profile, headwind: settings.windAdjustsClubs ? headwind : nil) {
                label(icon: "sparkles",
                      text: String(localized: "建議 \(s.club.displayName)（\(settings.format(meters: s.expected))）"),
                      dim: false)
            }
        }
    }

    private func label(icon: String, text: String, dim: Bool) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(dim ? Theme.textSecondary : Theme.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
    }
}
