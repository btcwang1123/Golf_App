import Charts
import GolfKit
import SwiftUI

/// Landing spots relative to the start → target line (up = toward the target, right = right miss).
struct DispersionChart: View {
    let points: [DispersionPoint]
    let settings: AppSettings

    var body: some View {
        Chart {
            RuleMark(x: .value("偏差", 0)).foregroundStyle(Theme.hairline)
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                PointMark(x: .value("左右", settings.displayValue(meters: p.lateral)),
                          y: .value("距離", settings.displayValue(meters: p.along)))
                    .foregroundStyle(Theme.gold.opacity(0.75))
                    .symbolSize(30)
            }
        }
        .chartXScale(domain: -60...60)
        .chartXAxisLabel(position: .bottom, alignment: .center) { Text("← 左 · 右 →").font(.caption2) }
        .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(Theme.hairline); AxisValueLabel() } }
        .accessibilityLabel("落點散佈，共 \(points.count) 球")
    }
}
