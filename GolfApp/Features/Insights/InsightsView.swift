import GolfKit
import SwiftData
import SwiftUI

/// Statistics tab: trends, scoring structure, clubs and strokes gained.
struct InsightsView: View {
    enum Range: Int, CaseIterable, Identifiable {
        case five = 5, ten = 10, twenty = 20, all = 0
        var id: Int { rawValue }
        var title: String { self == .all ? "全部" : "最近 \(rawValue) 場" }
        var lastN: Int? { self == .all ? nil : rawValue }
    }

    @Environment(CourseRepository.self) private var repository
    @Environment(AppRouter.self) private var router
    @Query(sort: \RoundRecord.startedAt, order: .reverse) private var records: [RoundRecord]

    @State private var range: Range = .ten
    @State private var courseFilter: String?
    @State private var summary: InsightsSummary?
    @State private var states: [RoundState] = []
    @State private var courseMap: [String: Course] = [:]
    @State private var unlocks: [AchievementUnlock] = []

    private var courseNames: [(id: String, name: String)] {
        var seen = Set<String>()
        return records.compactMap { r in seen.insert(r.courseId).inserted ? (r.courseId, r.courseName) : nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filters
                    journeyLinks
                    if let summary, summary.hasEnoughData {
                        tiles(summary)
                        toParCard(summary)
                        ScoringDistributionChart(breakdown: summary.breakdown).card()
                        ParTypeCard(averages: summary.parTypeAverage)
                        puttsCard(summary)
                        firGirCard(summary)
                        links
                    } else if summary != nil {
                        EmptyStateView(icon: "chart.line.uptrend.xyaxis", title: "再打幾場就有趨勢了",
                                       message: "完成 3 場回合後，這裡會出現成績走勢、上果嶺率與推桿分析。",
                                       actionTitle: "去找球場", action: { router.tab = .courses })
                            .frame(minHeight: 380)
                    } else {
                        ProgressView().tint(Theme.gold).frame(maxWidth: .infinity).padding(60)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .background(PremiumBackground())
            .navigationTitle("統計")
            .task(id: "\(range.rawValue)-\(courseFilter ?? "")-\(records.count)") { compute() }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("場數", selection: $range) {
                ForEach(Range.allCases) { Text(LocalizedStringKey($0.title)).tag($0) }
            }
            .pickerStyle(.segmented)
            Menu {
                Button("全部球場") { courseFilter = nil }
                ForEach(courseNames, id: \.id) { c in Button(c.name) { courseFilter = c.id } }
            } label: {
                Label(courseFilter.flatMap { id in courseNames.first { $0.id == id }?.name } ?? String(localized: "全部球場"),
                      systemImage: "line.3.horizontal.decrease.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
        .padding(.top, 8)
    }

    private func tiles(_ s: InsightsSummary) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: "平均桿", value: Self.format(s.averageScore18 ?? s.averageScore9),
                     unit: s.averageScore18 == nil && s.averageScore9 != nil ? "9 洞" : nil, accent: Theme.gold)
            StatTile(title: "最佳", value: (s.best18 ?? s.best9).map(String.init) ?? "—")
            StatTile(title: "平均 +/-", value: s.averageToPar.map { String(format: "%+.1f", $0) } ?? "—")
            StatTile(title: "FIR", value: RoundDetailView.percent(s.firPercent))
            StatTile(title: "GIR", value: RoundDetailView.percent(s.girPercent))
            StatTile(title: "推桿/洞", value: s.puttsPerHole.map { String(format: "%.2f", $0) } ?? "—")
        }
    }

    private func toParCard(_ s: InsightsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "對標準桿差", trailing: "金線為 3 場移動平均")
            TrendChart(points: s.trend.compactMap { p in p.toPar.map { (p.date, Double($0) * 18 / Double(max(p.holes, 1))) } },
                       movingAverageWindow: 3, valueLabel: "+/-")
                .frame(height: 180)
                .card()
            if s.averageScore9 != nil && s.averageScore18 != nil {
                Text("9 洞回合已換算為 18 洞比較；平均桿數分開計算。")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func puttsCard(_ s: InsightsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "推桿趨勢", trailing: "每洞")
            TrendChart(points: s.trend.compactMap { p in p.puttsPerHole.map { (p.date, $0) } }, movingAverageWindow: 3, valueLabel: "推桿")
                .frame(height: 150)
                .card()
        }
    }

    private func firGirCard(_ s: InsightsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "FIR / GIR 趨勢", trailing: "%")
            FirGirChart(points: s.trend)
                .frame(height: 160)
                .card()
            if s.trend.contains(where: \.isManual) {
                Text("手動輸入的回合只計入桿數、推桿與 GIR。")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var links: some View {
        VStack(spacing: 0) {
            NavigationLink { ClubDistancesView(states: states, courses: courseMap) } label: {
                linkRow("figure.golf", "球桿距離與落點")
            }
            Divider().overlay(Theme.hairline).padding(.leading, 56)
            NavigationLink { StrokesGainedView(states: states, courses: courseMap) } label: {
                linkRow("chart.bar.xaxis", "Strokes Gained（估算）")
            }
            Divider().overlay(Theme.hairline).padding(.leading, 56)
            NavigationLink { ShortGameView(states: states, courses: courseMap) } label: {
                linkRow("circle.dotted.circle", "短桿與推桿")
            }

        }
        .buttonStyle(.plain)
        .card(padding: 0)
    }

    private var journeyLinks: some View {
        VStack(spacing: 12) {
        HStack(spacing: 12) {
            NavigationLink { AchievementsView(unlocks: unlocks) } label: {
                journeyTile("rosette", "成就", "\(unlocks.count)/\(Achievement.allCases.count)")
            }
            NavigationLink { RecapView() } label: {
                journeyTile("calendar", "回顧", String(localized: "\(String(Calendar.current.component(.year, from: Date()))) 年"))
            }
        }
            NavigationLink { TempoPracticeView(states: states) } label: {
                journeyTile("metronome", "揮桿節奏與練習場", String(localized: "Apple Watch 練習場模式"))
            }
        }
        .buttonStyle(.plain)
    }

    private func journeyTile(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ivory)
                Text(verbatim: value).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 14, corner: Theme.cornerSmall + 4)
    }

    private func linkRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Theme.gold).frame(width: 26)
            Text(LocalizedStringKey(title)).foregroundStyle(Theme.ivory)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private func compute() {
        let filtered = records.filter { ($0.totalStrokes ?? 0) > 0 && (courseFilter == nil || $0.courseId == courseFilter) }
        var map: [String: Course] = [:]
        let s = filtered.map { r -> RoundState in
            let c = repository.course(id: r.courseId)
            if let c { map[r.courseId] = c }
            return RoundStore.state(of: r, course: c)
        }
        states = range.lastN.map { Array(s.prefix($0)) } ?? s
        courseMap = map
        summary = InsightsSummary.make(rounds: s, courses: map, lastN: range.lastN)
        let all = records.filter { ($0.totalStrokes ?? 0) > 0 && $0.endedAt != nil }
            .map { RoundStore.state(of: $0, course: repository.course(id: $0.courseId)) }
        unlocks = AchievementEngine.unlocks(rounds: all)
    }

    static func format(_ v: Double?) -> String { v.map { String(format: "%.1f", $0) } ?? "—" }
}
