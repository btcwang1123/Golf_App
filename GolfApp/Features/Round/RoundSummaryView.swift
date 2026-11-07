import GolfKit
import SwiftUI

/// Shown right after a round ends: score, key stats, scorecard and share.
struct RoundSummaryView: View {
    let roundId: UUID
    var onDone: () -> Void
    /// Optional extra action (showcase: "開始我的第一場").
    var primaryTitle: LocalizedStringKey?
    var onPrimary: (() -> Void)?

    @Environment(RoundStore.self) private var roundStore
    @Environment(CourseRepository.self) private var courses
    @Environment(SettingsService.self) private var settings
    @State private var showShare = false
    @State private var appeared = false
    @State private var unlocked: [AchievementUnlock] = []

    var body: some View {
        if let record = roundStore.record(id: roundId) {
            let course = courses.course(id: record.courseId)
            let state = RoundStore.state(of: record, course: course)
            let stats = RoundStats(state: state, course: course)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("回合完成")
                        Text(verbatim: record.courseName)
                            .font(Theme.display(28))
                            .foregroundStyle(Theme.ivory)
                    }
                    HStack {
                        Spacer()
                        ScoreRing(total: state.totalStrokes, toPar: state.toPar, size: 150)
                            .scaleEffect(appeared ? 1 : 0.7)
                            .opacity(appeared ? 1 : 0)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        StatTile(title: "推桿", value: "\(stats.totalPutts)")
                        StatTile(title: "GIR", value: RoundDetailView.percent(stats.girPercent))
                        StatTile(title: "博蒂+", value: "\(RoundHighlights(state: state).birdiesOrBetter)", accent: Theme.gold)
                    }
                    NewAchievementsCard(unlocks: unlocked)
                    SettlementCard(state: state, course: course)
                    PaceSummaryCard(round: state)
                    if state.players.count > 1 {
                        GroupScorecardCard(round: state, holeCount: max(state.holesPlayed, 9) > 9 ? 18 : 9)
                    } else {
                        ScorecardCard(holes: state.holes.filter { $0.number <= (state.holesPlayed > 9 ? 18 : 9) })
                    }
                    Button { showShare = true } label: { Label("分享成績卡", systemImage: "square.and.arrow.up") }
                        .buttonStyle(GoldButtonStyle())
                    if let primaryTitle, let onPrimary {
                        Button(action: onPrimary) { Text(primaryTitle) }
                            .buttonStyle(GhostButtonStyle(tint: Theme.gold))
                    }
                    Button("完成", action: onDone)
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(Theme.gutter)
            }
            .onAppear { withAnimation(Motion.hero.delay(0.15)) { appeared = true } }
            .task(id: roundId) { computeUnlocks() }
            .sheet(isPresented: $showShare) {
                ScorecardShareView(round: state, course: course, courseName: record.courseName,
                                   events: roundStore.events(of: record))
            }
        } else {
            EmptyStateView(icon: "flag.checkered", title: "回合已結束", message: "可在歷史中查看。",
                           actionTitle: "完成", action: onDone)
        }
    }

    private func computeUnlocks() {
        let all = roundStore.history().filter { $0.endedAt != nil }
            .map { RoundStore.state(of: $0, course: courses.course(id: $0.courseId)) }
        let fresh = AchievementEngine.newlyUnlocked(in: roundId, rounds: all)
        withAnimation(Motion.hero.delay(0.4)) { unlocked = fresh }
        if !fresh.isEmpty { Haptics.play(.birdie) }
    }
}
