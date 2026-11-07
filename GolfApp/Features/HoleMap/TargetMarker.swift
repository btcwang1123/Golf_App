import GolfKit
import SwiftUI

/// Draggable aim point.
struct TargetMarker: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(MapPalette.target, lineWidth: 2).frame(width: 30, height: 30)
            Circle().fill(MapPalette.target).frame(width: 6, height: 6)
        }
        .frame(width: Theme.tapTarget, height: Theme.tapTarget)
        .contentShape(Circle())
        .shadow(color: Theme.scrim, radius: 2)
        .accessibilityLabel("目標點，可拖曳")
    }
}

/// Small distance capsule drawn on the map.
struct MapDistanceLabel: View {
    let text: String
    var emphasized = false

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: emphasized ? 13 : 11, weight: .bold).monospacedDigit())
            .foregroundStyle(emphasized ? Theme.onGold : Theme.ivory)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(emphasized ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.scrim)))
    }
}
