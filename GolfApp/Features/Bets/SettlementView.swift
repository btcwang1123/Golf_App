import GolfKit
import SwiftUI

/// Who pays whom; per-game breakdown below.
struct SettlementCard: View {
    let state: RoundState
    let course: Course?

    private var result: BetSettlement { BetSettlement.compute(state: state, course: course) }

    private func name(_ id: UUID) -> String { state.players.first { $0.id == id }?.name ?? "—" }

    var body: some View {
        let r = result
        if !r.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "賭局結算", trailing: state.isEnded ? nil : "進行中")
                VStack(spacing: 0) {
                    ForEach(Array(state.players.enumerated()), id: \.element.id) { i, p in
                        HStack {
                            Text(verbatim: p.name).foregroundStyle(Theme.ivory)
                            Spacer()
                            Text(Self.money(r.totals[p.id] ?? 0))
                                .font(Theme.numeral(20, weight: .regular))
                                .foregroundStyle(Self.tint(r.totals[p.id] ?? 0))
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                        if i < state.players.count - 1 { Divider().overlay(Theme.hairline) }
                    }
                }
                .card(padding: 0)
                if !r.transfers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("怎麼付", color: Theme.textSecondary)
                        ForEach(r.transfers, id: \.self) { t in
                            HStack(spacing: 8) {
                                Text(verbatim: name(t.from)).foregroundStyle(Theme.ivory)
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(Theme.gold)
                                Text(verbatim: name(t.to)).foregroundStyle(Theme.ivory)
                                Spacer()
                                Text(verbatim: "\(t.amount)").font(Theme.numeral(17, weight: .medium)).foregroundStyle(Theme.gold)
                            }
                            .font(.subheadline)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(name(t.from)) 付給 \(name(t.to)) \(t.amount)")
                        }
                    }
                    .card()
                }
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(r.games, id: \.game) { g in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(String(localized: String.LocalizationValue(g.game.title))) · 每注 \(g.stake)")
                                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.gold)
                                ForEach(state.players) { p in
                                    HStack {
                                        Text(verbatim: p.name).font(.caption).foregroundStyle(Theme.ivory)
                                        Text(LocalizedStringKey(g.notes[p.id] ?? "")).font(.caption).foregroundStyle(Theme.textSecondary)
                                        Spacer()
                                        Text(Self.money(g.net[p.id] ?? 0)).font(.caption.monospacedDigit())
                                            .foregroundStyle(Self.tint(g.net[p.id] ?? 0))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("各賭局明細").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                .card()
                ShareLink(item: shareText(r)) {
                    Label("分享結算", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GhostButtonStyle(compact: true))
            }
        }
    }

    static func money(_ v: Int) -> String { v == 0 ? "±0" : v > 0 ? "+\(v)" : "−\(-v)" }
    static func tint(_ v: Int) -> Color { v > 0 ? Theme.fairway : v < 0 ? Theme.danger : Theme.textSecondary }

    private func shareText(_ r: BetSettlement) -> String {
        var lines = [String(localized: "⛳️ 今日結算")]
        for p in state.players { lines.append("\(p.name)  \(Self.money(r.totals[p.id] ?? 0))") }
        if !r.transfers.isEmpty {
            lines.append("")
            for t in r.transfers { lines.append("\(name(t.from)) → \(name(t.to))  \(t.amount)") }
        }
        return lines.joined(separator: "\n")
    }
}

/// Wolf of the current hole picks a partner or goes alone.
struct WolfPickBar: View {
    let state: RoundState
    let hole: Int
    let onPick: (UUID?) -> Void

    var body: some View {
        if let bets = state.bets, bets.amount(for: .wolf) > 0, BetConfig.Game.wolf.allows(playerCount: state.players.count),
           let wolf = BetSettlement.wolf(on: hole, players: state.players) {
            let pick = state.wolfPicks[hole]
            Menu {
                ForEach(state.players.filter { $0.id != wolf.id }) { p in
                    Button(p.name) { onPick(p.id) }
                }
                Button("單挑（雙倍）", systemImage: "person.fill") { onPick(nil) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill").foregroundStyle(Theme.gold)
                    Text("地主 \(wolf.name)").font(.footnote.weight(.semibold)).foregroundStyle(Theme.ivory)
                    Spacer()
                    Text(pickLabel(pick)).font(.footnote).foregroundStyle(pick == nil ? Theme.warning : Theme.gold)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.hairline))
            }
            .accessibilityLabel("鬥地主選隊友")
        }
    }

    private func pickLabel(_ pick: WolfPick?) -> String {
        guard let pick else { return String(localized: "選隊友") }
        guard let id = pick.partnerId else { return String(localized: "單挑") }
        return String(localized: "隊友 \(state.players.first { $0.id == id }?.name ?? "")")
    }
}
