import GolfKit
import SwiftUI

/// Nearest course with a low-poly first hole, distance, data level and a start button.
struct NearbyCourseHeroCard: View {
    let item: CourseListItem
    let onStart: () -> Void

    private var firstHole: Hole? { item.course.holes.first { HoleQuality.evaluate($0).isPlayable } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: item.course) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let firstHole {
                            HoleThumbnail(hole: firstHole, course: item.course)
                        } else {
                            Theme.heroGradient.overlay(
                                Image(systemName: "flag.fill").font(.system(size: 44, weight: .light)).foregroundStyle(Theme.gold.opacity(0.5)))
                        }
                    }
                    .frame(height: 170)
                    LinearGradient(colors: [.clear, Theme.background.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Eyebrow(item.distanceMeters == nil ? "常去球場" : "離你最近")
                            if item.isFeatured { FeaturedBadge() }
                            QualityTag(level: item.quality)
                        }
                        Text(verbatim: item.course.name)
                            .font(Theme.display(26, weight: .medium))
                            .foregroundStyle(Theme.ivory)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        if let d = item.distanceMeters {
                            Text(verbatim: CourseRowView.kilometers(d))
                                .font(Theme.numeral(14, weight: .regular))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(18)
                }
            }
            .buttonStyle(.plain)
            Button(action: onStart) {
                Label("開始回合", systemImage: "figure.golf")
            }
            .buttonStyle(GoldButtonStyle())
            .padding(16)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.hairline))
    }
}
