import GolfKit
import SwiftUI

struct RoundDetailView: View {
    let record: RoundRecord

    @Environment(CourseRepository.self) private var repository
    @State private var state: RoundState?
    @State private var stats: RoundStats?
    @State private var showEdit = false
    @State private var showShare = false
    @Environment(RoundStore.self) private var roundStore
    @Environment(HolePlanStore.self) private var plans

    private var isManual: Bool { state.map(ManualHoleScore.isManual) ?? false }

    var body: some View {
        let course = repository.course(id: record.courseId)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let state {
                    hero(state)
                    statGrid
                    PaceSummaryCard(round: state)
                    if let adherence = HolePlan.adherence(plans: plans.plans(courseId: record.courseId), round: state) {
                        planCard(adherence)
                    }
                    if state.players.count > 1 {
                        GroupScorecardCard(round: state, holeCount: playedRange(state).count)
                        LeaderboardInline(state: state, course: course)
                    } else {
                        ScorecardCard(holes: playedRange(state))
                    }
                    SettlementCard(state: state, course: course)
                    RoundPhotoStrip(roundId: record.id)
                    holeList(state, course: course)
                } else {
                    ProgressView().tint(Theme.gold).frame(maxWidth: .infinity).padding(60)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .background(PremiumBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let state, state.totalStrokes > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("分享", systemImage: "square.and.arrow.up") { showShare = true }
                }
            }
            if isManual, record.endedAt != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("編輯", systemImage: "square.and.pencil") { showEdit = true }
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: reload) {
            ManualRoundEntryView(editing: record)
        }
        .sheet(isPresented: $showShare) {
            if let state {
                ScorecardShareView(round: state, course: repository.course(id: record.courseId),
                                   courseName: record.courseName, events: roundStore.events(of: record))
            }
        }
        .task(id: record.id) { reload() }
    }

    private func reload() {
        let course = repository.course(id: record.courseId)
        let s = RoundStore.state(of: record, course: course)
        state = s
        stats = RoundStats(state: s, course: course)
    }

    /// Holes up to the last one played (keeps 9-hole rounds from showing 18 empty columns).
    private func playedRange(_ state: RoundState) -> [HoleState] {
        let last = state.holes.filter { $0.total > 0 }.map(\.number).max() ?? 0
        let upTo = last <= 9 && state.holes.count >= 9 ? 9 : state.holes.count
        return state.holes.filter { $0.number <= upTo }
    }

    private func hero(_ state: RoundState) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(record.startedAt.formatted(.dateTime.year().month().day().weekday(.abbreviated)))
                Text(verbatim: record.courseName)
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                if isManual { Tag(text: "手動記錄", color: Theme.textSecondary) }
            }
            Spacer()
            ScoreRing(total: state.totalStrokes, toPar: state.toPar, size: 92)
        }
        .padding(.top, 8)
    }

    @Environment(SettingsService.self) private var settingsService

    private func planCard(_ a: (holes: Int, averageMiss: Double)) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "scope").font(.title3).foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("攻略執行").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ivory)
                Text("開球平均偏離目標 \(settingsService.settings.format(meters: a.averageMiss))（\(a.holes) 洞）")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .card()
    }

    private var statGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: "推桿", value: "\(stats?.totalPutts ?? 0)",
                     unit: stats?.puttsPerHole.map { String(format: "%.1f / 洞", $0) })
            StatTile(title: "罰桿", value: "\(stats?.totalPenalties ?? 0)")
            if !isManual {
                StatTile(title: "上球道 FIR", value: Self.percent(stats?.firPercent))
            }
            StatTile(title: "標準上果嶺 GIR", value: Self.percent(stats?.girPercent))
        }
    }

    @ViewBuilder
    private func holeList(_ state: RoundState, course: Course?) -> some View {
        let played = state.holes.filter { $0.total > 0 }
        if let course, !isManual, !played.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "擊球回放")
                VStack(spacing: 0) {
                    ForEach(Array(played.enumerated()), id: \.element.number) { index, hole in
                        NavigationLink {
                            HoleReplayView(course: course, holeNumber: hole.number, shots: hole.shots)
                        } label: {
                            HStack(spacing: 14) {
                                Text("\(hole.number)")
                                    .font(Theme.numeral(15, weight: .medium))
                                    .foregroundStyle(Theme.gold)
                                    .frame(width: 28)
                                Text("第 \(hole.number) 洞")
                                    .foregroundStyle(Theme.ivory)
                                Text(hole.par.map { "Par \($0)" } ?? "")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                ScoreMark(strokes: hole.total, par: hole.par, size: 28)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < played.count - 1 {
                            Divider().overlay(Theme.hairline).padding(.leading, 58)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.hairline))
            }
        }
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }
}

/// Classic split scorecard (OUT / IN) with circle/square score notation.
struct ScorecardCard: View {
    let holes: [HoleState]

    private var halves: [[HoleState]] {
        guard holes.count > 9 else { return [holes] }
        let mid = (holes.count + 1) / 2
        return [Array(holes.prefix(mid)), Array(holes.dropFirst(mid))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "計分卡")
            VStack(spacing: 14) {
                ForEach(Array(halves.enumerated()), id: \.offset) { index, half in
                    nine(half, label: halves.count == 1 ? "TOT" : (index == 0 ? "OUT" : "IN"))
                }
                legend
            }
            .card(padding: 14)
        }
    }

    private func nine(_ holes: [HoleState], label: String) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 8) {
            GridRow {
                header("洞")
                ForEach(holes, id: \.number) { header("\($0.number)") }
                header(label, gold: true)
            }
            GridRow {
                rowTitle("PAR")
                ForEach(holes, id: \.number) { h in
                    Text(h.par.map(String.init) ?? "–")
                        .font(Theme.numeral(12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                Text(sum(holes.compactMap(\.par)))
                    .font(Theme.numeral(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            GridRow {
                rowTitle("桿")
                ForEach(holes, id: \.number) { h in
                    ScoreMark(strokes: h.total > 0 ? h.total : nil, par: h.par, size: 26)
                        .frame(maxWidth: .infinity)
                }
                Text(sum(holes.map(\.total)))
                    .font(Theme.numeral(15, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity)
            }
            GridRow {
                rowTitle("推")
                ForEach(holes, id: \.number) { h in
                    Text(h.total > 0 ? "\(h.putts)" : "–")
                        .font(Theme.numeral(12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                Text(sum(holes.map(\.putts)))
                    .font(Theme.numeral(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func header(_ text: String, gold: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(gold ? Theme.gold : Theme.textTertiary)
            .frame(maxWidth: .infinity)
    }

    private func rowTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.textTertiary)
            .frame(width: 30, alignment: .leading)
    }

    private func sum(_ values: [Int]) -> String {
        let s = values.reduce(0, +)
        return s > 0 ? "\(s)" : "–"
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([ScoreTone.eagle, .birdie, .bogey, .double], id: \.self) { tone in
                HStack(spacing: 5) {
                    Circle().fill(tone.color).frame(width: 6, height: 6)
                    Text(tone.label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

/// Compact standings for a finished group round.
struct LeaderboardInline: View {
    let state: RoundState
    let course: Course?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "排行榜", trailing: state.game.kind.title)
            VStack(spacing: 8) {
                ForEach(GameScorer.standings(state: state, course: course)) { s in
                    HStack {
                        Text(verbatim: "\(s.rank)").font(Theme.numeral(15, weight: .semibold))
                            .foregroundStyle(s.rank == 1 ? Theme.gold : Theme.textSecondary).frame(width: 22)
                        Text(verbatim: state.players.first { $0.id == s.playerId }?.name ?? "")
                            .foregroundStyle(Theme.ivory)
                        Spacer()
                        Text(LocalizedStringKey(s.detail)).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .card(padding: 14)
        }
    }
}
