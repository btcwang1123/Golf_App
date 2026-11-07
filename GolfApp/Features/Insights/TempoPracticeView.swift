import Charts
import GolfKit
import SwiftUI

/// Swing tempo from rounds and range sessions recorded on Apple Watch.
struct TempoPracticeView: View {
    let states: [RoundState]

    @Environment(PracticeStore.self) private var practice

    var body: some View {
        let sessions = practice.sessions()
        let round = TempoStats.make(rounds: states)
        let range = TempoStats.make(sessions: sessions)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    tempoTile("下場節奏", round)
                    tempoTile("練習場節奏", range)
                }
                Text("節奏 = 上桿時間 ÷ 下桿時間。職業選手平均約 3:1，越穩定越好。需要 Apple Watch 自動偵測揮桿。")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                clubCard(round, range)
                SectionTitle(title: "練習場紀錄", trailing: sessions.isEmpty ? nil : "\(sessions.count)")
                if sessions.isEmpty {
                    Text("在 Apple Watch 開啟「練習場模式」，每次揮桿都會自動計數並分析節奏。")
                        .font(.footnote).foregroundStyle(Theme.textSecondary).card()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { i, s in
                            sessionRow(s)
                            if i < sessions.count - 1 { Divider().overlay(Theme.hairline) }
                        }
                    }
                    .card(padding: 0)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .background(PremiumBackground())
        .navigationTitle("揮桿節奏與練習")
    }

    private func tempoTile(_ title: String, _ t: TempoStats) -> some View {
        StatTile(title: title, value: t.average.map { String(format: "%.1f:1", $0) } ?? "—",
                 unit: t.idealShare.map { String(localized: "理想 \(Int(($0 * 100).rounded()))%") },
                 accent: t.average.map { TempoStats.rating($0) == .ideal ? Theme.fairway : Theme.warning } ?? Theme.ivory)
    }

    @ViewBuilder
    private func clubCard(_ round: TempoStats, _ range: TempoStats) -> some View {
        let clubs = Club.allCases.filter { round.byClub[$0] != nil || range.byClub[$0] != nil }
        if !clubs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "各球桿節奏")
                Chart {
                    RuleMark(y: .value("理想", TempoStats.ideal)).foregroundStyle(Theme.fairway.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    ForEach(clubs, id: \.self) { c in
                        if let v = round.byClub[c] {
                            BarMark(x: .value("球桿", c.displayName), y: .value("節奏", v))
                                .foregroundStyle(by: .value("來源", String(localized: "下場")))
                                .position(by: .value("來源", String(localized: "下場")))
                        }
                        if let v = range.byClub[c] {
                            BarMark(x: .value("球桿", c.displayName), y: .value("節奏", v))
                                .foregroundStyle(by: .value("來源", String(localized: "練習場")))
                                .position(by: .value("來源", String(localized: "練習場")))
                        }
                    }
                }
                .chartForegroundStyleScale([String(localized: "下場"): Theme.gold, String(localized: "練習場"): Theme.bogey])
                .frame(height: 190)
                .card()
            }
        }
    }

    private func sessionRow(_ s: PracticeSession) -> some View {
        let t = s.tempo
        return HStack(spacing: 14) {
            Image(systemName: "figure.golf").foregroundStyle(Theme.gold).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.startedAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(Theme.ivory)
                Text("\(s.swings.count) 次揮桿 · \(Int(s.duration / 60)) 分鐘" + (s.club.map { " · \($0.displayName)" } ?? ""))
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(verbatim: t.average.map { String(format: "%.1f:1", $0) } ?? "—")
                .font(Theme.numeral(17, weight: .regular))
                .foregroundStyle(t.average.map { TempoStats.rating($0) == .ideal ? Theme.fairway : Theme.warning } ?? Theme.textSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contextMenu {
            Button("刪除", systemImage: "trash", role: .destructive) { practice.delete(id: s.id) }
        }
        .accessibilityElement(children: .combine)
    }
}
