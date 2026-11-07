import GolfKit
import SwiftUI

struct CourseRowView: View {
    let item: CourseListItem
    var compact = false

    var body: some View {
        HStack(spacing: 14) {
            monogram
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: item.course.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if item.isFeatured { FeaturedBadge() }
                    QualityTag(level: item.quality)
                    if let county = item.course.county {
                        Text(verbatim: county)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            if let meters = item.distanceMeters {
                Text(Self.kilometers(meters))
                    .font(Theme.numeral(14, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
            if !compact {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var monogram: some View {
        Text(verbatim: String(item.course.name.prefix(1)))
            .font(Theme.display(18, weight: .medium))
            .foregroundStyle(Theme.gold)
            .frame(width: Theme.iconButton, height: Theme.iconButton)
            .background(Circle().fill(Theme.gold.opacity(0.08)))
            .overlay(Circle().strokeBorder(Theme.gold.opacity(item.isFeatured ? 0.8 : 0.3), lineWidth: 0.75))
            .accessibilityHidden(true)
    }

    static func kilometers(_ meters: Double) -> String {
        String(format: "%.1f km", meters / 1000)
    }
}
