import GolfKit
import SwiftUI

/// Standings for the active game; can switch the game mid-round.
struct LeaderboardView: View {
    let state: RoundState
    let course: Course?
    var onChangeGame: ((GameFormat) -> Void)?
    var onChangeBets: ((BetConfig) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var game: GameFormat = .stroke
    @State private var editing = false
    @State private var bets = BetConfig()
    @State private var editingBets = false

    private var standings: [Standing] { GameScorer.standings(state: state, course: course) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Eyebrow(state.game.kind.title + (state.game.useHandicap ? " · 淨桿" : ""))
                        Spacer()
                        if onChangeGame != nil {
                            Button(editing ? "完成" : "變更玩法") {
                                if editing, game != state.game { onChangeGame?(game) }
                                withAnimation(Motion.snappy) { editing.toggle() }
                            }
                            .font(.footnote)
                        }
                    }
                    if editing {
                        GameSetupView(game: $game, playerCount: state.players.count, course: course)
                            .card()
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(standings.enumerated()), id: \.element.id) { i, s in
                            row(s)
                            if i < standings.count - 1 { Divider().overlay(Theme.hairline) }
                        }
                    }
                    .card(padding: 0)
                    SettlementCard(state: state, course: course)
                    if onChangeBets != nil {
                        Button(editingBets ? "完成賭局設定" : (state.bets == nil ? "加入賭局" : "變更賭局")) {
                            if editingBets, bets != (state.bets ?? BetConfig()) { onChangeBets?(bets) }
                            withAnimation(Motion.snappy) { editingBets.toggle() }
                        }
                        .font(.footnote)
                        if editingBets {
                            BetSetupView(config: $bets, players: state.players).card()
                        }
                    }
                }
                .padding(Theme.gutter)
            }
            .background(PremiumBackground())
            .navigationTitle("排行榜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("關閉") { dismiss() } } }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .onAppear {
            game = state.game
            bets = state.bets ?? BetConfig()
        }
    }

    private func row(_ s: Standing) -> some View {
        let player = state.players.first { $0.id == s.playerId }
        let toPar = state.toPar(for: s.playerId)
        return HStack(spacing: 14) {
            Text(verbatim: "\(s.rank)")
                .font(Theme.numeral(20, weight: .semibold))
                .foregroundStyle(s.rank == 1 && s.holesPlayed > 0 ? Theme.gold : Theme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: player?.name ?? "—")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ivory)
                Text(LocalizedStringKey(s.detail))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: "\(s.gross)")
                    .font(Theme.numeral(22, weight: .regular))
                    .foregroundStyle(Theme.ivory)
                    .contentTransition(.numericText())
                Text(ScoreFormat.toPar(toPar))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(s.rank) 名 \(player?.name ?? "")，總桿 \(s.gross)，\(s.detail)")
    }
}
