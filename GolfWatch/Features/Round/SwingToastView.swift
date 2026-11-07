import GolfKit
import SwiftUI

/// Shown after an auto-detected swing: cancel it or add a penalty stroke.
struct SwingToastView: View {
    let toast: WatchRoundStore.Toast
    let onUndo: () -> Void
    let onPenalty: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("揮桿 +1")
                    .font(.footnote.weight(.semibold))
                if let tempo = toast.tempo, TempoStats.plausible.contains(tempo) {
                    Text(verbatim: String(format: "%.1f:1", tempo))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(TempoStats.rating(tempo) == .ideal ? .green : .orange)
                        .accessibilityLabel("節奏 \(String(format: "%.1f", tempo)) 比 1")
                }
            }
            HStack(spacing: 6) {
                Button("取消", role: .destructive, action: onUndo)
                Button("+1 罰桿", action: onPenalty)
            }
            .font(.footnote)
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .id(toast.id)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
