import Charts
import GolfKit
import SwiftUI

struct ScoringDistributionChart: View {
    let breakdown: ScoringBreakdown

    private func color(_ b: ScoringBreakdown.Bucket) -> Color {
        switch b {
        case .eagle: Theme.eagle
        case .birdie: Theme.birdie
        case .par: Theme.ivory
        case .bogey: Theme.bogey
        case .doublePlus: Theme.doubleBogey
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "成績分布", trailing: "\(breakdown.total) 洞")
            Chart(ScoringBreakdown.Bucket.allCases, id: \.self) { b in
                BarMark(x: .value("類別", String(localized: String.LocalizationValue(b.title))),
                        y: .value("比例", breakdown.share(b) * 100))
                    .foregroundStyle(color(b))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text(verbatim: "\(Int((breakdown.share(b) * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.textSecondary) }
            }
            .frame(height: 150)
        }
    }
}
