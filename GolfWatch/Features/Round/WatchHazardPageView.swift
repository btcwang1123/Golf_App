import GolfKit
import SwiftUI

/// Second page: hazards ahead with front / carry distances, and today's pin preset.
struct WatchHazardPageView: View {
    @Environment(WatchRoundStore.self) private var store
    @Environment(WatchSettingsService.self) private var settings

    var body: some View {
        let s = settings.settings
        List {
            if store.currentHole?.pinPresets() != nil {
                Section("旗桿位置") {
                    HStack(spacing: 4) {
                        pinButton("前", .front)
                        pinButton("中", .center)
                        pinButton("後", .back)
                    }
                }
            }
            Section("障礙物") {
                if store.hazards.isEmpty {
                    Text(store.currentHole == nil ? "此洞無圖資" : "前方沒有障礙物")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.hazards) { h in
                    HStack {
                        Image(systemName: h.kind == .bunker ? "circle.dotted" : "drop.fill")
                            .foregroundStyle(Color(mapHex: MapColors.fill(for: h.kind)))
                        Text(verbatim: Self.side(h.side))
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(verbatim: s.format(meters: h.front)).font(.system(.body, design: .rounded).weight(.semibold))
                            Text(verbatim: s.format(meters: h.carry)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(h.kind == .bunker ? "沙坑" : "水障礙")，前緣 \(s.format(meters: h.front))，飛越 \(s.format(meters: h.carry))")
                }
            }
        }
        .onAppear { store.refreshHazards(force: true) }
    }

    private func pinButton(_ title: String, _ preset: WatchRoundStore.PinPreset) -> some View {
        Button(LocalizedStringKey(title)) { store.setPin(preset) }
            .buttonStyle(.bordered)
            .font(.footnote.weight(.semibold))
    }

    static func side(_ s: HazardDistance.Side) -> String {
        switch s {
        case .left: "左"
        case .center: "中"
        case .right: "右"
        }
    }
}

extension Color {
    /// 0xRRGGBB from `GolfKit.MapColors`.
    init(mapHex hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
