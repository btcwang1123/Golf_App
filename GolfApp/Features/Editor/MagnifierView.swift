import GolfKit
import MapKit
import SwiftUI

/// Close-up imagery around the dragged vertex so the finger does not hide it.
struct MagnifierView: View {
    let point: GeoPoint
    var size: CGFloat = 120
    static let distance = 70.0

    var body: some View {
        Map(position: .constant(.camera(MapCamera(centerCoordinate: point.coordinate, distance: Self.distance, heading: 0, pitch: 0)))) {}
            .mapStyle(.imagery)
            .allowsHitTesting(false)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.gold, lineWidth: 2))
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
            .shadow(radius: 6)
            .accessibilityHidden(true)
    }
}
