import GolfKit
import SwiftUI

/// Stakes per money game. Shown when the round has at least two players.
struct BetSetupView: View {
    @Binding var config: BetConfig
    let players: [Player]

    static let presets = [0, 10, 20, 50, 100, 200, 500]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(BetConfig.Game.allCases) { game in
                let allowed = game.allows(playerCount: players.count)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(LocalizedStringKey(game.title)).foregroundStyle(allowed ? Theme.ivory : Theme.textTertiary)
                        Spacer()
                        Menu {
                            ForEach(Self.presets, id: \.self) { v in
                                Button(v == 0 ? String(localized: "不玩") : "\(v)") { config.setAmount(v, for: game) }
                            }
                        } label: {
                            Text(config.amount(for: game) == 0 ? String(localized: "不玩") : String(localized: "每注 \(config.amount(for: game))"))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(config.amount(for: game) > 0 ? Theme.gold : Theme.textSecondary)
                        }
                        .disabled(!allowed)
                    }
                    Text(LocalizedStringKey(allowed ? game.explanation : Self.requirement(game)))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if game == .vegas, allowed, config.amount(for: .vegas) > 0 { vegasTeams }
                }
            }
            Toggle("以差點計算淨桿", isOn: $config.useHandicap).tint(Theme.gold)
            Text("金額只用來記帳結算，App 不會收付任何款項。")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    static func requirement(_ g: BetConfig.Game) -> String {
        switch g {
        case .vegas: "拉斯維加斯需要剛好 4 人。"
        case .wolf: "鬥地主需要 3–4 人。"
        default: "需要至少 2 人。"
        }
    }

    private var teamA: [UUID] {
        config.vegasTeam.count == 2 ? config.vegasTeam : Array(players.prefix(2).map(\.id))
    }

    private var vegasTeams: some View {
        HStack(spacing: 8) {
            Text("隊友").font(.caption).foregroundStyle(Theme.textSecondary)
            ForEach(players.dropFirst()) { p in
                let selected = teamA.contains(p.id)
                Button {
                    if let owner = players.first { config.vegasTeam = [owner.id, p.id] }
                } label: {
                    Text(verbatim: p.name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(selected ? Theme.onGold : Theme.ivory)
                        .background(Capsule().fill(selected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surfaceRaised)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
