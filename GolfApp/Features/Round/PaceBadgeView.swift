import GolfKit
import SwiftUI

/// Elapsed time and pace versus 14 min / hole.
struct PaceBadgeView: View {
    let round: RoundState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let pace = PaceOfPlay(state: round, now: ctx.date)
            HStack(spacing: 6) {
                Image(systemName: "timer").font(.caption2)
                Text(verbatim: PaceOfPlay.format(pace.elapsed)).font(.caption.monospacedDigit().weight(.semibold))
                if let status = pace.status() { Text(Self.label(status)).font(.caption2).foregroundStyle(Self.color(status)) }
            }
            .foregroundStyle(Theme.ivory)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Theme.surface.opacity(0.85)))
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("已打 \(PaceOfPlay.format(pace.elapsed))")
        }
    }

    static func label(_ s: PaceOfPlay.Status) -> String {
        switch s {
        case .ahead(let m): String(localized: "快 \(m) 分")
        case .onPace: String(localized: "正常")
        case .behind(let m): String(localized: "慢 \(m) 分")
        }
    }

    static func color(_ s: PaceOfPlay.Status) -> Color {
        switch s {
        case .ahead, .onPace: Theme.fairway
        case .behind: Theme.warning
        }
    }
}

/// Duration summary for finished rounds.
struct PaceSummaryCard: View {
    let round: RoundState
    var body: some View {
        let pace = PaceOfPlay(state: round, now: round.endedAt ?? Date())
        if pace.elapsed > 60, pace.holesCompleted > 0 {
            HStack(spacing: 12) {
                StatTile(title: "總時間", value: PaceOfPlay.format(pace.elapsed))
                StatTile(title: "每洞", value: pace.averageMinutesPerHole.map { "\(Int($0.rounded()))" } ?? "—", unit: "分")
                if let slow = pace.slowestHole {
                    StatTile(title: "最久", value: "\(slow.hole)", unit: String(localized: "洞 · \(Int((slow.seconds / 60).rounded())) 分"))
                }
            }
        }
    }
}
