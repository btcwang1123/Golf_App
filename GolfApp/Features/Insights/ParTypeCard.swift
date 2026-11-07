import GolfKit
import SwiftUI

/// Average score on par 3 / 4 / 5 holes.
struct ParTypeCard: View {
    let averages: [Int: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "各類洞平均")
            HStack(spacing: 12) {
                ForEach([3, 4, 5], id: \.self) { par in
                    let avg = averages[par]
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow("PAR \(par)", color: Theme.textSecondary)
                        Text(avg.map { String(format: "%.2f", $0) } ?? "—")
                            .font(Theme.numeral(26))
                            .foregroundStyle(Theme.ivory)
                        Text(avg.map { String(format: "%+.2f", $0 - Double(par)) } ?? " ")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14, corner: Theme.cornerSmall)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
