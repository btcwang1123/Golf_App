import GolfKit
import SwiftUI

/// Median and p25–p75 per club, plus a dispersion plot for the selected club.
struct ClubDistancesView: View {
    let states: [RoundState]
    let courses: [String: Course]

    @Environment(SettingsService.self) private var settings
    @State private var profile = ClubProfile()
    @State private var selected: Club?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if profile.clubs.isEmpty {
                    EmptyStateView(icon: "figure.golf", title: "還沒有球桿資料",
                                   message: "回合中點擊某一桿並選擇球桿，就會累積距離資料。")
                        .frame(minHeight: 360)
                } else {
                    ranges
                    if let club = selected ?? profile.ordered.first?.club, let s = profile[club] {
                        SectionTitle(title: "\(club.displayName) 落點散佈", trailing: "\(s.dispersion.count) 球")
                        DispersionChart(points: s.dispersion, settings: settings.settings)
                            .frame(height: 260)
                            .card()
                    }
                    Text("已排除推桿、罰桿前的那一桿，以及短於 10 m 或長於 350 m 的異常值。")
                        .font(.caption2).foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(Theme.gutter)
        }
        .background(PremiumBackground())
        .navigationTitle("球桿距離")
        .task { profile = ClubProfile.build(rounds: states, courses: courses) }
    }

    private var ranges: some View {
        let ordered = profile.ordered
        let maxV = ordered.map(\.stats.p75).max() ?? 1
        return VStack(spacing: 14) {
            ForEach(ordered, id: \.club) { item in
                Button { selected = item.club } label: {
                    HStack(spacing: 12) {
                        Text(verbatim: item.club.displayName)
                            .font(Theme.numeral(14, weight: .semibold))
                            .foregroundStyle(selected == item.club ? Theme.gold : Theme.ivory)
                            .frame(width: 40, alignment: .leading)
                        GeometryReader { geo in
                            let w = geo.size.width
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.ivory.opacity(0.05))
                                Capsule().fill(Theme.goldGradient.opacity(0.5))
                                    .frame(width: max(4, w * (item.stats.p75 - item.stats.p25) / maxV))
                                    .offset(x: w * item.stats.p25 / maxV)
                                Circle().fill(Theme.ivory).frame(width: 8, height: 8)
                                    .offset(x: w * item.stats.median / maxV - 4)
                            }
                        }
                        .frame(height: 10)
                        Text(verbatim: settings.settings.format(meters: item.stats.median))
                            .font(Theme.numeral(13, weight: .regular))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 56, alignment: .trailing)
                        Text(verbatim: "×\(item.stats.count)")
                            .font(.caption2).foregroundStyle(Theme.textTertiary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.club.displayName) 中位數 \(settings.settings.format(meters: item.stats.median))，\(item.stats.count) 球")
            }
        }
        .card()
    }
}
