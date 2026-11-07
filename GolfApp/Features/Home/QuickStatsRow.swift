import GolfKit
import SwiftUI

/// Average score, GIR% and putts over recent rounds.
struct QuickStatsRow: View {
    let summary: InsightsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "最近表現", trailing: "\(summary.roundCount) 場")
            HStack(spacing: 12) {
                StatTile(title: "平均桿", value: InsightsView.format(summary.averageScore18 ?? summary.averageScore9), accent: Theme.gold)
                StatTile(title: "GIR", value: RoundDetailView.percent(summary.girPercent))
                StatTile(title: "平均推桿", value: summary.puttsPerHole.map { String(format: "%.1f", $0 * 18) } ?? "—")
            }
        }
    }
}
