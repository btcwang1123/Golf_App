import GolfKit
import SwiftUI

struct StrokeControlsView: View {
    let canUndo: Bool
    let onSwing: () -> Void
    let onPutt: () -> Void
    let onPenalty: (PenaltyReason?) -> Void
    let onUndo: () -> Void

    @State private var tick = 0

    var body: some View {
        HStack(spacing: 10) {
            Button { fire(onSwing) } label: {
                Label("揮桿", systemImage: "plus")
            }
            .buttonStyle(GoldButtonStyle(compact: false))
            .accessibilityLabel("記一桿揮桿")

            Button { fire(onPutt) } label: {
                Label("推桿", systemImage: "plus")
            }
            .buttonStyle(GhostButtonStyle(tint: Theme.gold))
            .accessibilityLabel("記一桿推桿")

            Menu {
                Menu {
                    ForEach(PenaltyReason.allCases, id: \.self) { r in
                        Button(LocalizedStringKey(r.title), systemImage: r.symbol) { onPenalty(r); Haptics.play(.warning) }
                    }
                } label: {
                    Label("+1 罰桿", systemImage: "exclamationmark.triangle")
                }
                Button("復原上一桿", systemImage: "arrow.uturn.backward", action: onUndo)
                    .disabled(!canUndo)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ivory)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.05)))
                    .overlay(Circle().strokeBorder(Theme.hairline))
            }
        }
    }

    private func fire(_ action: () -> Void) {
        action()
        tick += 1
    }

}

/// Horizontal list of this hole's shots.
struct ShotListView: View {
    let shots: [ShotInfo]
    let settings: AppSettings
    let onSelect: (ShotInfo) -> Void

    var body: some View {
        if shots.isEmpty {
            Text("尚無擊球記錄 · 長按地圖可補一桿")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 44)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                        Button { onSelect(shot) } label: { chip(index: index, shot: shot) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func chip(index: Int, shot: ShotInfo) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(Theme.numeral(12, weight: .semibold))
                .foregroundStyle(Theme.onGold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(shot.type == .putt ? Theme.fairway : Theme.gold))
            VStack(alignment: .leading, spacing: 0) {
                Text(shot.club?.displayName ?? RoundViewModel.typeName(shot.type))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ivory)
                Text(shot.distanceToNext.map { settings.format(meters: $0) }?.nilIfEmpty ?? "—")
                    .font(Theme.numeral(11, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(height: 44)
        .background(Capsule().fill(Theme.surfaceRaised))
        .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Pick a club for a shot, or delete it.
struct ShotEditSheet: View {
    let shot: ShotInfo
    let onClub: (Club) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(Club.allCases, id: \.self) { club in
                            let on = club == shot.club
                            Button { onClub(club); dismiss() } label: {
                                Text(club.displayName)
                                    .font(Theme.numeral(15, weight: on ? .semibold : .regular))
                                    .foregroundStyle(on ? Theme.onGold : Theme.ivory)
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .background(Capsule().fill(on ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.05))))
                                    .overlay(Capsule().strokeBorder(on ? .clear : Theme.hairline))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Eyebrow("選擇球桿")
                }
                .listRowBackground(Color.clear)
                Section {
                    Button("刪除此桿", role: .destructive) { onDelete(); dismiss() }
                        .themedRow()
                }
            }
            .premiumBackground()
            .navigationTitle("\(RoundViewModel.typeName(shot.type))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }
}
