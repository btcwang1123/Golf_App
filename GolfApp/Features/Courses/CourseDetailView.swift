import GolfKit
import SwiftUI

struct CourseDetailView: View {
    let course: Course

    @Environment(RoundStore.self) private var roundStore
    @Environment(CourseRepository.self) private var courses
    @Environment(AppRouter.self) private var router
    @Environment(SettingsService.self) private var settings
    @State private var showStart = false
    @State private var showEditor = false
    @State private var showManual = false
    @State private var showTeeTime = false

    /// Latest version of the course (user edits override the one passed in).
    private var current: Course { courses.course(id: course.id) ?? course }
    private var quality: CourseQuality { courses.quality(id: current.id) }

    private var parTotal: Int? {
        let pars = current.holes.compactMap(\.par)
        guard !current.holes.isEmpty, pars.count == current.holes.count else { return nil }
        return pars.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                if let first = current.holes.first(where: { HoleQuality.evaluate($0).isPlayable }) {
                    HoleThumbnail(hole: first, course: current)
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                }
                stats
                if current.holes.contains(where: { $0.par != nil }) { holeStrip }
                actions
                Text(GolfKit.mapAttribution)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .background(PremiumBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                CourseExportButton(course: current)
                Button("編輯球場", systemImage: "pencil") { showEditor = true }
            }
        }
        .sheet(isPresented: $showStart) {
            AddPlayersView(course: current) { friends, game, bets in
                roundStore.start(course: current, friends: friends, game: game, bets: bets)
                router.showRound = true
            }
        }
        .sheet(isPresented: $showEditor) { CourseEditorView(course: current) }
        .sheet(isPresented: $showManual) { ManualRoundEntryView(course: current) }
        .sheet(isPresented: $showTeeTime) { TeeTimeEditorView(course: current) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(current.county ?? "Golf Course")
            Text(verbatim: current.name)
                .font(Theme.display(34))
                .foregroundStyle(Theme.ivory)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if current.source == .featured { FeaturedBadge() }
                QualityTag(level: quality.level)
                if current.source == .user { Tag(text: "自訂") }
                if current.effectiveProvenance == .survey { Tag(text: "實地踩點", color: Theme.fairway) }
            }
        }
        .padding(.top, 8)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatTile(title: "洞數", value: current.holes.isEmpty ? "—" : "\(current.holes.count)")
            StatTile(title: "標準桿", value: parTotal.map(String.init) ?? "—")
            StatTile(title: "圖資完整度", value: "\(Int((quality.score * 100).rounded()))", unit: "%", accent: quality.level.tint)
        }
    }

    private var holeStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "球洞")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(current.holes, id: \.number) { hole in
                        let level = quality.hole(hole.number)?.level ?? .scoreOnly
                        VStack(spacing: 4) {
                            Text(verbatim: "\(hole.number)")
                                .font(Theme.numeral(18, weight: .regular))
                                .foregroundStyle(Theme.ivory)
                            Text(hole.par.map { "PAR \($0)" } ?? "—")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(Theme.textSecondary)
                            Circle().fill(level.tint).frame(width: 5, height: 5)
                        }
                        .frame(width: 56, height: 70)
                        .card(padding: 0, corner: Theme.cornerSmall)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("第 \(hole.number) 洞，\(level.label)")
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showStart = true
            } label: {
                Label("開始回合", systemImage: "figure.golf")
            }
            .buttonStyle(GoldButtonStyle())

            Button {
                showManual = true
            } label: {
                Label("手動記錄成績", systemImage: "square.and.pencil")
            }
            .buttonStyle(GhostButtonStyle())

            HStack(spacing: 12) {
                if current.holes.contains(where: { HoleQuality.evaluate($0).isPlayable }) {
                    NavigationLink { CoursePlanView(course: current) } label: {
                        Label("攻略規劃", systemImage: "scope")
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                }
                Button {
                    showTeeTime = true
                } label: {
                    Label("開球提醒", systemImage: "bell")
                }
                .buttonStyle(GhostButtonStyle(compact: true))
            }
        }
        .padding(.top, 6)
    }
}
