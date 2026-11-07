import GolfKit
import SwiftData
import SwiftUI

/// Home: where am I playing today, how did the last round go.
struct HomeView: View {
    @Environment(CourseRepository.self) private var courses
    @Environment(RoundStore.self) private var roundStore
    @Environment(LocationService.self) private var location
    @Environment(SettingsService.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(TeeTimeStore.self) private var teeTimes
    @Query(sort: \RoundRecord.startedAt, order: .reverse) private var records: [RoundRecord]

    @State private var startCourse: Course?
    @State private var shareRecord: RoundRecord?
    @State private var summary: InsightsSummary?
    @State private var editingTeeTime: TeeTime?

    static let showcaseHoldSeconds = 2.0

    private var lastRound: RoundRecord? { records.first { $0.endedAt != nil && ($0.totalStrokes ?? 0) > 0 } }

    private var heroCourse: CourseListItem? {
        if let here = location.current {
            return courses.list(query: "", near: here).first
        }
        if let fav = settings.settings.favoriteCourseId, let c = courses.course(id: fav) {
            return CourseListItem(course: c, distanceMeters: nil, quality: courses.quality(id: fav).level)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let active = roundStore.active, !active.isEnded {
                        ContinueRoundCard(round: active, courseName: roundStore.activeCourse?.name ?? "") { router.showRound = true }
                    } else if let hero = heroCourse {
                        NearbyCourseHeroCard(item: hero) { startCourse = hero.course }
                    } else if courses.isLoaded {
                        searchEntry
                    } else {
                        RoundedRectangle(cornerRadius: Theme.corner).fill(Theme.skeleton).frame(height: 260)
                            .redacted(reason: .placeholder)
                    }
                    if let next = teeTimes.upcoming.first {
                        UpcomingTeeTimeCard(teeTime: next) { editingTeeTime = next }
                    }
                    if let lastRound {
                        LastRoundCard(record: lastRound, onShare: { shareRecord = lastRound })
                    }
                    if records.contains(where: { $0.endedAt != nil && ($0.totalStrokes ?? 0) > 0 }) {
                        recapTeaser
                    }
                    if let summary, summary.roundCount > 0 {
                        QuickStatsRow(summary: summary)
                    }
                    if records.isEmpty {
                        showcaseTeaser
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .background(PremiumBackground())
            .navigationDestination(for: RoundRecord.self) { RoundDetailView(record: $0) }
            .navigationDestination(for: Course.self) { CourseDetailView(course: $0) }
            .task(id: records.count) {
                computeSummary()
                WidgetSnapshotService.update(records: records, courses: courses, teeTimes: teeTimes.all)
            }
            .onChange(of: teeTimes.all) {
                WidgetSnapshotService.update(records: records, courses: courses, teeTimes: teeTimes.all)
            }
            .sheet(item: $editingTeeTime) { t in
                if let c = courses.course(id: t.courseId) { TeeTimeEditorView(course: c, existing: t) }
            }
            .task { if location.isAuthorized { location.start() } }
            .sheet(item: $startCourse) { course in
                AddPlayersView(course: course) { friends, game, bets in
                    roundStore.start(course: course, friends: friends, game: game, bets: bets)
                    router.showRound = true
                }
            }
            .sheet(item: $shareRecord) { r in
                let course = courses.course(id: r.courseId)
                ScorecardShareView(round: RoundStore.state(of: r, course: course), course: course,
                                   courseName: r.courseName, events: roundStore.events(of: r))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(Date().formatted(.dateTime.weekday(.wide).month().day()))
            Text(LocalizedStringKey(Self.greeting))
                .font(Theme.display(34))
                .foregroundStyle(Theme.ivory)
                .onLongPressGesture(minimumDuration: Self.showcaseHoldSeconds) {
                    Haptics.play(.birdie)
                    router.showShowcase = true
                }
                .accessibilityAction(named: "看展示") { router.showShowcase = true }
        }
        .padding(.top, 12)
    }

    private var searchEntry: some View {
        Button { router.tab = .courses } label: {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass").font(.title3).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("找球場").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ivory)
                    Text("全台 \(courses.all().count) 座球場，不用註冊").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var recapTeaser: some View {
        NavigationLink { RecapView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles").font(.title2).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(Calendar.current.component(.year, from: Date()))) 年度回顧")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ivory)
                    Text("場數、最佳成績、博蒂與成就，一張圖分享").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var showcaseTeaser: some View {
        Button { router.showShowcase = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.rectangle.fill").font(.title2).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("看 30 秒展示").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ivory)
                    Text("不用下場，先看一場完整的回合").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func computeSummary() {
        let recent = records.prefix(10).map { RoundStore.state(of: $0, course: courses.course(id: $0.courseId)) }
        var map: [String: Course] = [:]
        for r in records.prefix(10) { if let c = courses.course(id: r.courseId) { map[r.courseId] = c } }
        summary = InsightsSummary.make(rounds: Array(recent), courses: map, lastN: 10)
    }

    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "早安，今天打一場？"
        case 12..<18: "午安，準備開球"
        default: "晚安，回顧你的成績"
        }
    }
}


/// "繼續第 N 洞" when a round is in progress.
struct ContinueRoundCard: View {
    let round: RoundState
    let courseName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.fairway).frame(width: 7, height: 7)
                        Eyebrow("進行中的回合", color: Theme.fairway)
                    }
                    Text("繼續第 \(round.currentHole) 洞")
                        .font(Theme.display(28, weight: .medium))
                        .foregroundStyle(Theme.ivory)
                    (Text(verbatim: "\(courseName) · ") + Text("總桿 \(round.totalStrokes)"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.onGold)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Theme.goldGradient))
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.heroGradient))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("繼續第 \(round.currentHole) 洞，\(courseName)")
    }
}
