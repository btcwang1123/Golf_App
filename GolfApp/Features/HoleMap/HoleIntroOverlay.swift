import GolfKit
import SwiftUI

/// Hole number, par, length and handicap shown during the flyover.
struct HoleIntroOverlay: View {
    let hole: Hole
    let lengthMeters: Double?
    let settings: AppSettings

    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Hole")
            Text(verbatim: "\(hole.number)")
                .font(Theme.display(64))
                .foregroundStyle(Theme.ivory)
            HStack(spacing: 14) {
                if let par = hole.par { info("PAR", "\(par)") }
                if let l = lengthMeters { info(settings.distanceUnit == .yard ? "YDS" : "M", "\(Int(settings.displayValue(meters: l).rounded()))") }
                if let h = hole.handicap { info("HCP", "\(h)") }
            }
            Text("點一下跳過")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(LinearGradient(colors: [.clear, Theme.background.opacity(0.85)], startPoint: .center, endPoint: .bottom))
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .onAppear { withAnimation(Motion.hero.delay(0.2)) { visible = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(hole.number) 洞，標準桿 \(hole.par ?? 0)")
    }

    private func info(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: title).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Theme.gold)
            Text(verbatim: value).font(Theme.numeral(24, weight: .regular)).foregroundStyle(Theme.ivory)
        }
    }
}
