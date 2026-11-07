import GolfKit
import SwiftUI
import WidgetKit

struct RoundEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot?
    let unit: String
    var relevance: TimelineEntryRelevance? { snapshot == nil ? nil : TimelineEntryRelevance(score: 100) }
}

struct RoundComplicationProvider: TimelineProvider {
    static let unitKey = "complicationUnit"

    func placeholder(in context: Context) -> RoundEntry {
        RoundEntry(date: Date(), snapshot: ComplicationSnapshot(hole: 7, strokes: 31, distanceToPin: 140), unit: "y")
    }

    func getSnapshot(in context: Context, completion: @escaping (RoundEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RoundEntry>) -> Void) {
        let entry = current()
        // The app reloads timelines on strokes and hole changes; refresh hourly so stale rounds disappear.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }

    private func current() -> RoundEntry {
        let defaults = UserDefaults(suiteName: ComplicationSnapshot.appGroup)
        let snap = defaults?.data(forKey: ComplicationSnapshot.defaultsKey)
            .flatMap { try? JSONDecoder().decode(ComplicationSnapshot.self, from: $0) }
        let unit = defaults?.string(forKey: Self.unitKey) ?? "y"
        return RoundEntry(date: Date(), snapshot: snap.flatMap { $0.isStale() ? nil : $0 }, unit: unit)
    }
}

struct RoundComplication: Widget {
    static let kind = "RoundComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RoundComplicationProvider()) { entry in
            RoundComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("回合")
        .description("洞號與到果嶺距離")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct RoundComplicationView: View {
    let entry: RoundEntry
    @Environment(\.widgetFamily) private var family

    private var distance: String {
        guard let d = entry.snapshot?.distanceToPin else { return "--" }
        let v = entry.unit == "m" ? d : d / AppSettings.metersPerYard
        return "\(Int(v.rounded()))"
    }

    var body: some View {
        if let s = entry.snapshot {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(verbatim: "H\(s.hole)").font(.system(size: 11, weight: .semibold))
                    Text(verbatim: distance).font(.system(size: 20, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
                }
                .widgetAccentable()
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("第 \(s.hole) 洞 · \(s.strokes) 桿").font(.headline).widgetAccentable()
                    Text(verbatim: "\(distance)\(entry.unit)").font(.system(size: 26, weight: .bold, design: .rounded))
                }
            case .accessoryInline:
                Text("第 \(s.hole) 洞 \(distance)\(entry.unit)")
            default:
                Text(verbatim: distance).font(.system(size: 18, weight: .bold, design: .rounded))
                    .widgetLabel { Text(verbatim: "H\(s.hole)") }
            }
        } else {
            switch family {
            case .accessoryInline:
                Text("開始回合")
            case .accessoryRectangular:
                Label("開始回合", systemImage: "figure.golf").font(.headline)
            default:
                Image(systemName: "figure.golf").font(.title3).widgetAccentable()
            }
        }
    }
}
