import Charts
import GolfKit
import SwiftUI

/// Scrambling, bunker saves, putting from distance and penalty sources.
struct ShortGameView: View {
    let states: [RoundState]
    let courses: [String: Course]

    @Environment(SettingsService.self) private var settings

    var body: some View {
        let s = ShortGameStats.make(rounds: states, courses: courses)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: cols, spacing: 12) {
                    StatTile(title: "救球 Up & Down", value: RoundDetailView.percent(s.upAndDown.percent),
                             unit: "\(s.upAndDown.made)/\(s.upAndDown.chances)", accent: Theme.gold)
                    StatTile(title: "沙坑救球", value: RoundDetailView.percent(s.sandSave.percent),
                             unit: "\(s.sandSave.made)/\(s.sandSave.chances)")
                    StatTile(title: "一推", value: "\(s.onePutts)", unit: share(s.onePutts, s.holesWithPutts))
                    StatTile(title: "三推+", value: "\(s.threePutts)", unit: share(s.threePutts, s.holesWithPutts),
                             accent: s.threePutts > 0 ? Theme.bogey : Theme.ivory)
                }
                puttCard(s)
                penaltyCard(s)
                Text("救球：未標準上果嶺仍保住 Par 或更好。沙坑救球：果嶺旁沙坑兩桿內進洞。第一推距離需要推桿時有 GPS 位置。")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .background(PremiumBackground())
        .navigationTitle("短桿與推桿")
    }

    private func share(_ n: Int, _ d: Int) -> String? {
        d > 0 ? "\(Int((Double(n) / Double(d) * 100).rounded()))%" : nil
    }

    @ViewBuilder
    private func puttCard(_ s: ShortGameStats) -> some View {
        let buckets = s.puttBuckets.filter { $0.attempts > 0 }
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "第一推進洞率", trailing: s.averageFirstPuttMeters.map { String(localized: "平均 \(String(format: "%.1f", $0)) m") })
            if buckets.isEmpty {
                Text("推桿時開啟定位就能分析不同距離的進洞率。")
                    .font(.footnote).foregroundStyle(Theme.textSecondary).card()
            } else {
                Chart(buckets) { b in
                    BarMark(x: .value("距離", b.label), y: .value("進洞率", b.makePercent ?? 0))
                        .foregroundStyle(Theme.goldGradient)
                        .annotation(position: .top) {
                            Text(verbatim: "\(b.made)/\(b.attempts)").font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { AxisGridLine().foregroundStyle(Theme.hairline); AxisValueLabel() } }
                .frame(height: 180)
                .card()
            }
        }
    }

    @ViewBuilder
    private func penaltyCard(_ s: ShortGameStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "罰桿來源", trailing: "\(s.totalPenalties)")
            VStack(spacing: 10) {
                ForEach(PenaltyReason.allCases, id: \.self) { r in
                    let n = s.penaltiesByReason[r] ?? 0
                    if n > 0 { penaltyRow(Label(LocalizedStringKey(r.title), systemImage: r.symbol), n, s.totalPenalties) }
                }
                if s.unlabeledPenalties > 0 {
                    penaltyRow(Label("未標記", systemImage: "questionmark"), s.unlabeledPenalties, s.totalPenalties)
                }
                if s.totalPenalties == 0 {
                    Text("沒有罰桿，保持下去！").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .card()
        }
    }

    private func penaltyRow(_ label: Label<Text, Image>, _ n: Int, _ total: Int) -> some View {
        HStack {
            label.font(.subheadline).foregroundStyle(Theme.ivory)
            Spacer()
            GeometryReader { g in
                Capsule().fill(Theme.danger.opacity(0.7))
                    .frame(width: g.size.width * CGFloat(n) / CGFloat(max(total, 1)))
            }
            .frame(width: 90, height: 6)
            Text(verbatim: "\(n)").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.ivory).frame(width: 28, alignment: .trailing)
        }
    }
}
