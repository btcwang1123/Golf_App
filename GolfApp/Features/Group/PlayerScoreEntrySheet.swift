import GolfKit
import SwiftUI

/// After a hole: one row per friend, default par, ± to adjust, one tap to confirm.
struct PlayerScoreEntrySheet: View {
    let hole: Int
    let par: Int?
    let players: [Player]
    let existing: [UUID: Int]
    let onConfirm: ([UUID: Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [UUID: Int] = [:]

    static let range = 1...15

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("第 \(hole) 洞" + (par.map { " · PAR \($0)" } ?? ""))
                    Text("朋友的桿數").font(Theme.display(22)).foregroundStyle(Theme.ivory)
                }
                Spacer()
                Button("跳過") { dismiss() }
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(players) { p in
                row(p)
            }
            Button {
                onConfirm(values)
                Haptics.play(.stroke)
                dismiss()
            } label: {
                Label("確認", systemImage: "checkmark")
            }
            .buttonStyle(GoldButtonStyle())
        }
        .padding(Theme.gutter)
        .background(PremiumBackground())
        .presentationDetents([.height(CGFloat(170 + players.count * 64))])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear {
            for p in players { values[p.id] = existing[p.id] ?? par ?? 4 }
        }
    }

    private func row(_ p: Player) -> some View {
        let v = values[p.id] ?? par ?? 4
        return HStack(spacing: 12) {
            Text(verbatim: p.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
            Spacer()
            stepButton("minus", enabled: v > Self.range.lowerBound) { values[p.id] = v - 1 }
                .accessibilityLabel("\(p.name) 減一桿")
            ScoreMark(strokes: v, par: par, size: 40)
                .contentTransition(.numericText(value: Double(v)))
                .animation(Motion.snappy, value: v)
                .accessibilityLabel("\(p.name) \(v) 桿")
            stepButton("plus", enabled: v < Self.range.upperBound) { values[p.id] = v + 1 }
                .accessibilityLabel("\(p.name) 加一桿")
        }
        .frame(height: 52)
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.play(.selection)
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(CircleIconButtonStyle(size: Theme.tapTarget))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }
}
