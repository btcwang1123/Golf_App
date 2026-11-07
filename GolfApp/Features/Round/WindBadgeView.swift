import GolfKit
import SwiftUI

/// Wind arrow relative to the hole, speed and temperature, with the Apple Weather mark.
struct WindBadgeView: View {
    let snapshot: WeatherSnapshot
    let holeBearing: Double

    private var components: (head: Double, cross: Double) {
        WindComponent.relative(windFromDeg: snapshot.windFromDeg, speed: snapshot.windSpeed, holeBearing: holeBearing)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(WindComponent.arrowRotation(windFromDeg: snapshot.windFromDeg, holeBearing: holeBearing)))
                    .foregroundStyle(Theme.gold)
                    .accessibilityHidden(true)
                Text(verbatim: "\(Int(snapshot.windSpeed.rounded())) m/s")
                    .font(Theme.numeral(14, weight: .semibold))
                Text(verbatim: "\(Int(snapshot.temperatureC.rounded()))°")
                    .font(Theme.numeral(14, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(LocalizedStringKey(WindComponent.describe(head: components.head, cross: components.cross)))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            if let legal = snapshot.legalURL {
                Link(destination: legal) {
                    if let mark = snapshot.attributionMarkURL {
                        AsyncImage(url: mark) { $0.resizable().scaledToFit() } placeholder: { Text(verbatim: " Weather") }
                            .frame(height: 10)
                    } else {
                        Text(verbatim: " Weather")
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(Theme.textTertiary)
                .accessibilityLabel("Apple 天氣法律資訊")
            }
        }
        .foregroundStyle(Theme.ivory)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }
}
