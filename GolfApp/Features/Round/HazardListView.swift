import GolfKit
import SwiftUI

/// Expandable list of bunkers / water ahead with front and carry distances.
struct HazardListView: View {
    let hazards: [HazardDistance]
    let settings: AppSettings
    @State private var expanded = false

    var body: some View {
        if !hazards.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(Motion.snappy) { expanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("障礙物 \(hazards.count)")
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                if expanded {
                    ForEach(hazards) { h in
                        HStack(spacing: 10) {
                            Image(systemName: Self.icon(h.kind))
                                .foregroundStyle(MapPalette.fill(for: h.kind))
                                .frame(width: 20)
                            Text(LocalizedStringKey(Self.name(h)))
                                .font(.subheadline)
                                .foregroundStyle(Theme.ivory)
                            Spacer()
                            distance("前緣", h.front)
                            distance("飛越", h.carry)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous).fill(Theme.surface))
        }
    }

    private func distance(_ title: String, _ m: Double) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(LocalizedStringKey(title)).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textTertiary)
            Text(verbatim: settings.format(meters: m)).font(Theme.numeral(15, weight: .regular)).foregroundStyle(Theme.ivory)
        }
        .frame(minWidth: 52, alignment: .trailing)
    }

    static func icon(_ kind: Feature.Kind) -> String {
        switch kind {
        case .water, .lateralWater: "drop.fill"
        default: "circle.dotted"
        }
    }

    static func name(_ h: HazardDistance) -> String {
        let kind = h.kind == .bunker ? "沙坑" : "水障礙"
        switch h.side {
        case .left: return "左側\(kind)"
        case .right: return "右側\(kind)"
        case .center: return "正前方\(kind)"
        }
    }
}
