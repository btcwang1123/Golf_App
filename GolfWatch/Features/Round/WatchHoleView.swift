import GolfKit
import SwiftUI

/// Main scoring page: hole info, distances and stroke buttons.
struct WatchHoleView: View {
    @Environment(WatchRoundStore.self) private var store
    @Environment(WatchSettingsService.self) private var settings

    var body: some View {
        let hole = store.currentHoleState
        VStack(spacing: 2) {
            header(hole)
            distances
            Spacer(minLength: 0)
            buttons
            if let warning = store.sensorWarning {
                Text(LocalizedStringKey(warning))
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }

    private func header(_ hole: HoleState) -> some View {
        HStack {
            Button { store.previousHole() } label: { Image(systemName: "chevron.left") }
                .frame(width: 34)
                .disabled(store.currentHoleNumber <= 1)
            VStack(spacing: 0) {
                Text(verbatim: "第 \(store.currentHoleNumber) 洞" + (store.par.map { "  Par \($0)" } ?? ""))
                    .font(.footnote.weight(.semibold))
                Text(verbatim: "本洞 \(hole.total)  總 \(store.totalStrokes)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .minimumScaleFactor(0.7)
            Button { store.nextHole() } label: { Image(systemName: "chevron.right") }
                .frame(width: 34)
                .disabled(store.currentHoleNumber >= store.maxHole)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var distances: some View {
        let s = settings.settings
        if let d = store.greenDistances {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if store.pin != nil {
                    Text("旗").font(.caption2.weight(.bold)).foregroundStyle(.red)
                }
                Text(verbatim: s.format(meters: d.center))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(store.pin != nil ? "到旗桿 \(s.format(meters: d.center))" : "到果嶺中心 \(s.format(meters: d.center))")
            Text(verbatim: "前 \(s.format(meters: d.front))   後 \(s.format(meters: d.back))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text(verbatim: "--")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(store.activeCourse == nil ? "尚無球場資料" : "等待定位")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if store.isOnGreen {
            VStack(spacing: 4) {
                puttButton.frame(minHeight: 50).doubleTapPrimary(true)
                manualButton
            }
        } else {
            HStack(spacing: 4) {
                puttButton
                manualButton.doubleTapPrimary(true)
            }
        }
    }

    private var puttButton: some View {
        Button { store.addStroke(.putt) } label: {
            Text("推桿+1").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private var manualButton: some View {
        Button { store.addStroke(.manual) } label: {
            Text("手動+1").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
    }
}


extension View {
    /// Double Tap (pinch twice, watchOS 11+) triggers this button.
    @ViewBuilder
    func doubleTapPrimary(_ enabled: Bool) -> some View {
        if #available(watchOS 11.0, *), enabled {
            handGestureShortcut(.primaryAction)
        } else {
            self
        }
    }
}
