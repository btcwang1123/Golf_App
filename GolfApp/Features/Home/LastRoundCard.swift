import GolfKit
import SwiftUI

/// Previous round: tap for details, share button.
struct LastRoundCard: View {
    let record: RoundRecord
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "上一場")
                Button("分享", systemImage: "square.and.arrow.up", action: onShare)
                    .labelStyle(.iconOnly)
                    .buttonStyle(CircleIconButtonStyle(size: 34))
                    .accessibilityLabel("分享上一場成績")
            }
            NavigationLink(value: record) {
                RoundRowCard(record: record)
            }
            .buttonStyle(.plain)
        }
    }
}
