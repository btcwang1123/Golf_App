import Charts
import GolfKit
import SwiftUI

/// Estimated strokes gained by category vs. a 15-handicap baseline.
struct StrokesGainedView: View {
    let states: [RoundState]
    let courses: [String: Course]

    @State private var total = SGBreakdown()
    @State private var rounds = 0

    private var rows: [(String, Double)] {
        let n = Double(max(rounds, 1))
        return [("開球", total.offTee / n), ("攻果嶺", total.approach / n), ("短桿", total.shortGame / n), ("推桿", total.putting / n)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("估算值，以業餘 15 差點為基準")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                if total.holesCounted == 0 {
                    EmptyStateView(icon: "chart.bar.xaxis", title: "尚無可計算的洞",
                                   message: "需要在「完整圖資」的球場、以 GPS 記錄每一桿。")
                        .frame(minHeight: 320)
                } else {
                    HStack(spacing: 12) {
                        StatTile(title: "每場總計", value: String(format: "%+.1f", total.total / Double(max(rounds, 1))), accent: Theme.gold)
                        StatTile(title: "計入洞數", value: "\(total.holesCounted)")
                    }
                    Chart(rows, id: \.0) { row in
                        BarMark(x: .value("SG", row.1), y: .value("類別", String(localized: String.LocalizationValue(row.0))))
                            .foregroundStyle(row.1 >= 0 ? Theme.fairway : Theme.birdie)
                            .annotation(position: row.1 >= 0 ? .trailing : .leading) {
                                Text(verbatim: String(format: "%+.2f", row.1)).font(.caption2).foregroundStyle(Theme.textSecondary)
                            }
                    }
                    .chartXAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Theme.hairline); AxisValueLabel() } }
                    .frame(height: 200)
                    .card()
                }
                if total.holesExcluded > 0 {
                    Text("已排除 \(total.holesExcluded) 洞（圖資不完整或缺少擊球定位）。")
                        .font(.caption).foregroundStyle(Theme.textTertiary)
                }
                Text("每桿 SG ＝ 擊球前期望桿數 − 擊球後期望桿數 − 1；罰桿再 −1。")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
            .padding(Theme.gutter)
        }
        .background(PremiumBackground())
        .navigationTitle("Strokes Gained")
        .task {
            var sum = SGBreakdown()
            var counted = 0
            for s in states where !s.isManualEntry {
                let sg = StrokesGained.compute(state: s, course: s.courseId.flatMap { courses[$0] })
                if sg.holesCounted > 0 { counted += 1 }
                sum = sum + sg
            }
            total = sum
            rounds = counted
        }
    }
}
