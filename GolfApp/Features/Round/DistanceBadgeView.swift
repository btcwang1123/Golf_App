import GolfKit
import SwiftUI

struct DistanceBadgeView: View {
    let distances: (front: Double, center: Double, back: Double)?
    let settings: AppSettings
    /// Center distance is to today's pin instead of the green center.
    var toPin = false

    @ScaledMetric(relativeTo: .largeTitle) private var mainSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var sideSize: CGFloat = 17
    /// Collapsed by default; the player taps to reveal front / center / back.
    @AppStorage("distanceBadgeExpanded") private var expanded = false

    var body: some View {
        Button {
            withAnimation(Motion.snappy) { expanded.toggle() }
        } label: {
            Group {
                if expanded { expandedContent } else { collapsedContent }
            }
            .padding(.horizontal, expanded ? 16 : 12)
            .padding(.vertical, expanded ? 10 : 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.background.opacity(0.55))))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .environment(\.colorScheme, .dark)
        .accessibilityHint(expanded ? "點兩下收起" : "點兩下顯示前、中、後距離")
    }

    private var collapsedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "ruler")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text("前中後")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ivory)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("果嶺距離，已收起")
    }

    private var expandedContent: some View {
        HStack(alignment: .bottom, spacing: 16) {
            item("前", distances?.front, a11y: "到果嶺前緣")
            item(toPin ? "旗" : "中", distances?.center, emphasized: true, a11y: toPin ? "到旗桿" : "到果嶺中心")
            item("後", distances?.back, a11y: "到果嶺後緣")
            Text(LocalizedStringKey(settings.unitSuffix))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 6)
                .accessibilityHidden(true)
        }
    }

    private func item(_ title: String, _ meters: Double?, emphasized: Bool = false, a11y: String) -> some View {
        let value = meters.map { Int(settings.displayValue(meters: $0).rounded()) }
        return VStack(spacing: 0) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(emphasized ? Theme.gold : Theme.textSecondary)
            Text(value.map(String.init) ?? "--")
                .font(Theme.numeral(emphasized ? mainSize : sideSize, weight: emphasized ? .regular : .light))
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(Motion.snappy, value: value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\(a11y) \($0) \(settings.unitSuffix)" } ?? "\(a11y) 無資料")
    }
}
