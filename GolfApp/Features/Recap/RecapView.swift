import GolfKit
import SwiftData
import SwiftUI

/// Month / year in golf, with a shareable card.
struct RecapView: View {
    @Environment(CourseRepository.self) private var courses
    @Environment(SettingsService.self) private var settings
    @Query(sort: \RoundRecord.startedAt, order: .reverse) private var records: [RoundRecord]

    @State private var states: [RoundState] = []
    @State private var unlocks: [AchievementUnlock] = []
    @State private var periods: [PeriodRecap.Period] = []
    @State private var period: PeriodRecap.Period?
    @State private var image: UIImage?

    private var recap: PeriodRecap? {
        period.map { PeriodRecap.make(period: $0, rounds: states, unlocks: unlocks) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if periods.isEmpty {
                    EmptyStateView(icon: "calendar", title: "還沒有回顧", message: "完成一場回合後，這裡會整理每月與年度的精彩數據。",
                                   actionTitle: nil, action: nil)
                        .frame(minHeight: 360)
                } else {
                    Picker("期間", selection: $period) {
                        ForEach(periods) { p in Text(Self.title(p)).tag(Optional(p)) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.gold)
                    if let recap {
                        RecapCardView(recap: recap, courseName: courseName, settings: settings.settings)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                        if let image {
                            let shared = Image(uiImage: image)
                            ShareLink(item: shared, preview: SharePreview(Text(Self.title(recap.period)), image: shared)) {
                                Label("分享回顧", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(GoldButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .background(PremiumBackground())
        .navigationTitle("回顧")
        .task(id: records.count) { load() }
        .task(id: period) { render() }
    }

    private func courseName(_ id: String) -> String? {
        courses.course(id: id)?.name ?? records.first { $0.courseId == id }?.courseName
    }

    private func load() {
        states = records.filter { $0.endedAt != nil }.map { RoundStore.state(of: $0, course: courses.course(id: $0.courseId)) }
        unlocks = AchievementEngine.unlocks(rounds: states)
        periods = PeriodRecap.availablePeriods(rounds: states)
        if period == nil || !(periods.contains { $0 == period }) { period = periods.first }
    }

    private func render() {
        guard let recap else { image = nil; return }
        let view = RecapCardView(recap: recap, courseName: courseName, settings: settings.settings)
            .frame(width: 390, height: 693)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        image = renderer.uiImage
    }

    static func title(_ p: PeriodRecap.Period) -> String {
        switch p {
        case .year(let y): String(localized: "\(String(y)) 年度回顧")
        case .month(let y, let m): String(localized: "\(String(y)) 年 \(m) 月")
        }
    }
}

/// The recap itself; also rendered as a 9:16 image.
struct RecapCardView: View {
    let recap: PeriodRecap
    let courseName: (String) -> String?
    let settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(AppBrand.displayName)
                Text(RecapView.title(recap.period))
                    .font(Theme.display(30, weight: .medium))
                    .foregroundStyle(Theme.ivory)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(recap.roundCount)").font(Theme.numeral(64)).foregroundStyle(Theme.gold)
                Text("場").foregroundStyle(Theme.textSecondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(recap.holesPlayed) 洞").foregroundStyle(Theme.ivory)
                    if recap.hoursPlayed >= 1 {
                        Text("\(Int(recap.hoursPlayed.rounded())) 小時在球場").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            grid
            if let best = recap.best18 ?? recap.best9 {
                highlight(icon: "trophy.fill", title: "最佳成績",
                          value: "\(best.strokes)" + (best.toPar.map { " (\(ScoreFormat.toPar($0)))" } ?? ""),
                          detail: [best.courseId.flatMap(courseName), best.date.formatted(date: .abbreviated, time: .omitted)]
                              .compactMap { $0 }.joined(separator: " · "))
            }
            if let fav = recap.favoriteCourse, let name = courseName(fav.id) {
                highlight(icon: "flag.fill", title: "最常去", value: name, detail: String(localized: "\(fav.rounds) 場"))
            }
            if let imp = recap.improvement, abs(imp) >= 0.5 {
                highlight(icon: imp > 0 ? "arrow.down.right" : "arrow.up.right", title: imp > 0 ? "進步" : "退步",
                          value: String(format: "%.1f", abs(imp)), detail: String(localized: "後半段平均每 18 洞"))
            }
            if !recap.unlocks.isEmpty {
                HStack(spacing: 8) {
                    ForEach(recap.unlocks.prefix(5)) { AchievementBadge(achievement: $0.achievement, size: 40) }
                    Spacer()
                    Text("解鎖 \(recap.unlocks.count) 項成就").font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Theme.background
                RadialGradient(colors: [Theme.backgroundTop, .clear], center: .init(x: 0.2, y: 0), startRadius: 10, endRadius: 420)
                RadialGradient(colors: [Theme.gold.opacity(0.14), .clear], center: .init(x: 1, y: 0), startRadius: 0, endRadius: 300)
            })
        .environment(\.colorScheme, .dark)
    }

    private var grid: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            mini("博蒂", "\(recap.birdies)", Theme.birdie)
            mini("老鷹+", "\(recap.eagles)", Theme.eagle)
            mini("Par", "\(recap.pars)", Theme.ivory)
            mini("平均桿", recap.averageScore18.map { String(format: "%.1f", $0) } ?? "—", Theme.ivory)
            mini("推桿/洞", recap.puttsPerHole.map { String(format: "%.2f", $0) } ?? "—", Theme.ivory)
            mini("最遠一桿", recap.longestShot.map { settings.format(meters: $0.meters) } ?? "—", Theme.gold)
            mini("球場", "\(recap.coursesPlayed)", Theme.ivory)
            mini("愛用球桿", recap.favoriteClub?.club.displayName ?? "—", Theme.ivory)
            mini("走了", recap.metersWalked > 0 ? String(format: "%.1f km", recap.metersWalked / 1000) : "—", Theme.fairway)
        }
    }

    private func mini(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title)).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            Text(verbatim: value).font(Theme.numeral(20, weight: .regular)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.cornerTiny, style: .continuous).fill(Theme.surface))
    }

    private func highlight(icon: String, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.gold).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.caption).foregroundStyle(Theme.textSecondary)
                Text(verbatim: value).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ivory).lineLimit(1)
            }
            Spacer()
            Text(verbatim: detail).font(.caption2).foregroundStyle(Theme.textTertiary).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
