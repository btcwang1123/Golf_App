import Charts
import GolfKit
import SwiftUI

/// Line chart with an optional trailing moving average.
struct TrendChart: View {
    let points: [(Date, Double)]
    var movingAverageWindow = 3
    var valueLabel: String = ""

    private var indexed: [(i: Int, date: Date, v: Double, avg: Double)] {
        let avg = InsightsSummary.movingAverage(points.map(\.1), window: movingAverageWindow)
        return points.enumerated().map { (i: $0.offset, date: $0.element.0, v: $0.element.1, avg: avg[$0.offset]) }
    }

    var body: some View {
        Chart {
            ForEach(indexed, id: \.i) { p in
                LineMark(x: .value("場次", p.i + 1), y: .value(valueLabel, p.v), series: .value("系列", "值"))
                    .foregroundStyle(Theme.ivory.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("場次", p.i + 1), y: .value(valueLabel, p.v))
                    .foregroundStyle(Theme.ivory.opacity(0.7))
                    .symbolSize(18)
                LineMark(x: .value("場次", p.i + 1), y: .value("平均", p.avg), series: .value("系列", "平均"))
                    .foregroundStyle(Theme.gold)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .accessibilityLabel("趨勢圖，共 \(points.count) 場")
    }
}

/// FIR% and GIR% per round.
struct FirGirChart: View {
    let points: [InsightsSummary.RoundPoint]

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                if let fir = p.firPercent {
                    LineMark(x: .value("場次", i + 1), y: .value("%", fir), series: .value("指標", "FIR"))
                        .foregroundStyle(by: .value("指標", "FIR"))
                }
                if let gir = p.girPercent {
                    LineMark(x: .value("場次", i + 1), y: .value("%", gir), series: .value("指標", "GIR"))
                        .foregroundStyle(by: .value("指標", "GIR"))
                }
            }
        }
        .chartForegroundStyleScale(["FIR": Theme.fairway, "GIR": Theme.gold])
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartLegend(position: .top, alignment: .leading)
    }
}
