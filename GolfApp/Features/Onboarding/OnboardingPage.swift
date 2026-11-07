import GolfKit
import SwiftUI

/// One onboarding page with an animated illustration.
struct OnboardingPage: View {
    enum Art { case watch, map, group }

    let art: Art
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    @State private var animate = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)
            illustration
                .frame(height: 260)
            VStack(spacing: 12) {
                Text(title)
                    .font(Theme.display(30, weight: .medium))
                    .foregroundStyle(Theme.ivory)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .onAppear { withAnimation(Motion.hero.repeatForever(autoreverses: true)) { animate = true } }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var illustration: some View {
        switch art {
        case .watch:
            ZStack {
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .fill(Theme.surfaceRaised)
                    .frame(width: 170, height: 205)
                    .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).strokeBorder(Theme.goldGradient, lineWidth: 2))
                VStack(spacing: 6) {
                    Text(verbatim: "152").font(Theme.numeral(54, weight: .semibold)).foregroundStyle(Theme.ivory)
                    Text(verbatim: animate ? "揮桿 +1" : " ").font(.headline).foregroundStyle(Theme.gold)
                        .opacity(animate ? 1 : 0)
                }
                Image(systemName: "figure.golf")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(Theme.gold)
                    .rotationEffect(.degrees(animate ? -18 : 12), anchor: .bottom)
                    .offset(x: 120, y: 60)
            }
        case .map:
            ZStack {
                HoleThumbnail(hole: ShowcaseScript.demoHole, showBackground: true)
                    .frame(width: 200, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    .rotation3DEffect(.degrees(animate ? 38 : 30), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .shadow(color: Theme.scrim, radius: 20, y: 20)
                Circle().fill(MapPalette.player).frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Theme.ivory, lineWidth: 2))
                    .offset(y: animate ? 30 : 90)
            }
        case .group:
            HStack(spacing: -14) {
                ForEach(Array(["我", "A", "B", "C"].enumerated()), id: \.offset) { i, n in
                    Text(verbatim: n)
                        .font(Theme.display(26, weight: .medium))
                        .foregroundStyle(i == 0 ? Theme.onGold : Theme.ivory)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(i == 0 ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surfaceRaised)))
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 3))
                        .offset(y: animate ? CGFloat(i % 2 == 0 ? -8 : 8) : 0)
                }
            }
        }
    }
}
