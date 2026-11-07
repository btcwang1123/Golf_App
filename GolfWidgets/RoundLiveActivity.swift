import ActivityKit
import GolfKit
import SwiftUI
import WidgetKit

/// Lock screen banner and Dynamic Island for a round in progress.
struct RoundLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(WidgetPalette.background)
                .activitySystemActionForegroundColor(WidgetPalette.gold)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("第 \(s.hole) 洞").font(.caption.weight(.semibold)).foregroundStyle(WidgetPalette.gold)
                        if let par = s.par { Text(verbatim: "PAR \(par)").font(.caption2).foregroundStyle(WidgetPalette.secondary) }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: "\(s.strokes)").font(.title2.weight(.semibold).monospacedDigit())
                        Text(verbatim: s.toParText).font(.caption.weight(.semibold)).foregroundStyle(WidgetPalette.gold)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: s.distanceText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WidgetPalette.ivory)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(verbatim: context.attributes.courseName).font(.caption2).foregroundStyle(WidgetPalette.secondary).lineLimit(1)
                }
            } compactLeading: {
                Text(verbatim: "\(s.hole)").font(.caption.weight(.bold)).foregroundStyle(WidgetPalette.gold)
            } compactTrailing: {
                Text(verbatim: s.distanceText).font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                Text(verbatim: "\(s.hole)").font(.caption.weight(.bold)).foregroundStyle(WidgetPalette.gold)
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: RoundActivityAttributes
    let state: RoundActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: attributes.courseName).font(.caption).foregroundStyle(WidgetPalette.secondary).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("第 \(state.hole) 洞").font(.headline).foregroundStyle(WidgetPalette.gold)
                    if let par = state.par { Text(verbatim: "PAR \(par)").font(.caption).foregroundStyle(WidgetPalette.secondary) }
                }
                Text("總桿 \(state.strokes) · \(state.toParText)").font(.subheadline.monospacedDigit()).foregroundStyle(WidgetPalette.ivory)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: state.distanceText)
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WidgetPalette.ivory)
                Text("到旗桿").font(.caption2).foregroundStyle(WidgetPalette.secondary)
            }
        }
        .padding(16)
    }
}
