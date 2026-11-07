import GolfKit
import SwiftUI

extension Achievement.Tier {
    var color: Color {
        switch self {
        case .bronze: Theme.goldDeep
        case .silver: Theme.ivory
        case .gold: Theme.eagle
        }
    }
}

/// Round medal with the achievement's symbol; dimmed while locked.
struct AchievementBadge: View {
    let achievement: Achievement
    var unlocked = true
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            Circle().fill(unlocked ? achievement.tier.color.opacity(0.16) : Theme.skeleton)
            Circle().strokeBorder(unlocked ? achievement.tier.color : Theme.hairline, lineWidth: 1.2)
            Image(systemName: achievement.symbol)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(unlocked ? achievement.tier.color : Theme.textTertiary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// All milestones; unlocked ones show the date.
struct AchievementsView: View {
    let unlocks: [AchievementUnlock]

    private var byId: [Achievement: AchievementUnlock] {
        Dictionary(unlocks.map { ($0.achievement, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        let have = byId
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    StatTile(title: "已解鎖", value: "\(have.count)", unit: "/ \(Achievement.allCases.count)", accent: Theme.gold)
                    StatTile(title: "金牌", value: "\(have.keys.filter { $0.tier == .gold }.count)")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(Achievement.allCases) { a in
                        let u = have[a]
                        VStack(spacing: 8) {
                            AchievementBadge(achievement: a, unlocked: u != nil)
                            Text(LocalizedStringKey(a.title))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(u != nil ? Theme.ivory : Theme.textSecondary)
                                .multilineTextAlignment(.center)
                            Text(u.map { $0.date.formatted(date: .numeric, time: .omitted) } ?? String(localized: String.LocalizationValue(a.detail)))
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
                        .card(padding: 12, corner: Theme.cornerSmall)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(u != nil ? "\(a.title)，已解鎖" : "\(a.title)，未解鎖，\(a.detail)")
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .background(PremiumBackground())
        .navigationTitle("成就")
    }
}

/// "本場解鎖" strip on the round summary.
struct NewAchievementsCard: View {
    let unlocks: [AchievementUnlock]

    var body: some View {
        if !unlocks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("本場解鎖")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(unlocks) { u in
                            VStack(spacing: 6) {
                                AchievementBadge(achievement: u.achievement, size: 58)
                                Text(LocalizedStringKey(u.achievement.title))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.ivory)
                            }
                            .frame(width: 86)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .card()
        }
    }
}
