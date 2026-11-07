import SwiftUI

/// Shared animation curves.
enum Motion {
    static let standard = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let snappy = Animation.spring(response: 0.26, dampingFraction: 0.78)
    static let hero = Animation.spring(response: 0.7, dampingFraction: 0.82)
    static let fade = Animation.easeInOut(duration: 0.35)
    static let celebrationDuration: Double = 0.8
    /// Dip-to-dark when switching holes.
    static let holeFadeOut: Double = 0.25
    static let holeFadeHold: Double = 0.1
    static let holeFadeIn: Double = 0.35
}

/// Golden glow shown briefly after a birdie or better.
struct CelebrationGlow: View {
    let trigger: Int
    @State private var visible = false

    var body: some View {
        RadialGradient(colors: [Theme.gold.opacity(0.55), Theme.gold.opacity(0.12), .clear],
                       center: .center, startRadius: 0, endRadius: 320)
            .scaleEffect(visible ? 1.15 : 0.6)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: trigger) {
                withAnimation(.easeOut(duration: Motion.celebrationDuration / 2)) { visible = true }
                Task {
                    try? await Task.sleep(for: .seconds(Motion.celebrationDuration / 2))
                    withAnimation(.easeIn(duration: Motion.celebrationDuration / 2)) { visible = false }
                }
            }
    }
}

/// Placeholder rows shown while data loads.
struct SkeletonRows: View {
    var count = 6

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 14) {
                    Circle().fill(Theme.skeleton).frame(width: Theme.iconButton, height: Theme.iconButton)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("高爾夫球場名稱佔位").font(.system(size: 16, weight: .medium))
                        Text("縣市").font(.footnote)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .redacted(reason: .placeholder)
        .foregroundStyle(Theme.textTertiary)
        .accessibilityLabel("載入中")
    }
}
