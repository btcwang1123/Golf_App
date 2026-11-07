import GolfKit
import SwiftUI
import WidgetKit

struct HomeStatsEntry: TimelineEntry {
    let date: Date
    let snapshot: HomeWidgetSnapshot
    let isPlaceholder: Bool
}

struct HomeStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeStatsEntry {
        HomeStatsEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeStatsEntry) -> Void) {
        completion(entry(preview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeStatsEntry>) -> Void) {
        // The app reloads the timeline whenever its data changes; refresh a few times a day for the tee-time countdown.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry(preview: false)], policy: .after(next)))
    }

    private func entry(preview: Bool) -> HomeStatsEntry {
        let snap = HomeWidgetSnapshot.load(from: UserDefaults(suiteName: HomeWidgetSnapshot.appGroup))
        return HomeStatsEntry(date: Date(), snapshot: snap ?? (preview ? .placeholder : HomeWidgetSnapshot()), isPlaceholder: snap == nil && preview)
    }
}

/// Last round, trend and next tee time on the home / lock screen.
struct HomeStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HomeStatsWidget", provider: HomeStatsProvider()) { entry in
            HomeStatsWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("高爾夫成績")
        .description("最近一場成績、走勢與下次開球。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct HomeStatsWidgetView: View {
    let entry: HomeStatsEntry
    @Environment(\.widgetFamily) private var family

    private var s: HomeWidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private static func toPar(_ v: Int?) -> String {
        guard let v else { return "—" }
        return v == 0 ? "E" : v > 0 ? "+\(v)" : "−\(-v)"
    }

    @ViewBuilder
    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "figure.golf").font(.title2).foregroundStyle(WidgetPalette.gold)
            Text("打完第一場就會顯示成績").font(.caption).foregroundStyle(WidgetPalette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var small: some View {
        if let r = s.lastRound {
            VStack(alignment: .leading, spacing: 4) {
                Text("最近一場").font(.system(size: 10, weight: .semibold)).foregroundStyle(WidgetPalette.gold)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "\(r.strokes)").font(.system(size: 40, weight: .light).monospacedDigit()).foregroundStyle(WidgetPalette.ivory)
                    Text(verbatim: Self.toPar(r.toPar)).font(.caption.weight(.semibold)).foregroundStyle(WidgetPalette.gold)
                }
                Text(verbatim: r.courseName).font(.caption2).foregroundStyle(WidgetPalette.secondary).lineLimit(1)
                Spacer(minLength: 0)
                if let next = s.nextTeeTime {
                    Label { Text(next.date, style: .relative) } icon: { Image(systemName: "bell") }
                        .font(.caption2).foregroundStyle(WidgetPalette.ivory).lineLimit(1)
                } else {
                    Text("今年 \(s.roundsThisYear) 場").font(.caption2).foregroundStyle(WidgetPalette.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            empty
        }
    }

    @ViewBuilder
    private var medium: some View {
        if s.lastRound == nil {
            empty
        } else {
            HStack(spacing: 16) {
                small
                VStack(alignment: .leading, spacing: 6) {
                    Text("對標準桿走勢").font(.system(size: 10, weight: .semibold)).foregroundStyle(WidgetPalette.gold)
                    Sparkline(values: s.trend).frame(maxHeight: .infinity)
                    HStack {
                        Text("平均 \(s.averageToPar.map { String(format: "%+.1f", $0) } ?? "—")")
                        Spacer()
                        Label("\(s.achievements)", systemImage: "rosette")
                    }
                    .font(.caption2).foregroundStyle(WidgetPalette.secondary)
                }
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let next = s.nextTeeTime {
                Text("下次開球").font(.caption2.weight(.semibold))
                Text(verbatim: next.courseName).font(.caption).lineLimit(1)
                Text(next.date, format: .dateTime.weekday().hour().minute()).font(.caption2)
            } else if let r = s.lastRound {
                Text("最近一場").font(.caption2.weight(.semibold))
                Text(verbatim: "\(r.strokes)  \(Self.toPar(r.toPar))").font(.headline.monospacedDigit())
                Text(verbatim: r.courseName).font(.caption2).lineLimit(1)
            } else {
                Text("高手").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "figure.golf").font(.caption2)
                Text(verbatim: s.lastRound.map { "\($0.strokes)" } ?? "—").font(.headline.monospacedDigit())
            }
        }
    }
}

/// Minimal line of recent to-par values (lower is better, drawn higher).
struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { g in
            if values.count >= 2, let lo = values.min(), let hi = values.max() {
                let span = max(hi - lo, 1)
                let pts = values.enumerated().map { i, v in
                    CGPoint(x: g.size.width * CGFloat(i) / CGFloat(values.count - 1),
                            y: g.size.height * CGFloat((v - lo) / span))
                }
                Path { p in p.addLines(pts) }
                    .stroke(WidgetPalette.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if let last = pts.last {
                    Circle().fill(WidgetPalette.gold).frame(width: 6, height: 6).position(last)
                }
            } else {
                Text("再打幾場").font(.caption2).foregroundStyle(WidgetPalette.secondary)
            }
        }
    }
}
