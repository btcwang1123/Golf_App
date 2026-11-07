import GolfKit
import SwiftUI

/// Today's pin; gold ring when it has been set by the user.
struct PinMarker: View {
    var isSet: Bool
    var editing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(systemName: "flag.fill")
                .font(.system(size: 20))
                .foregroundStyle(MapPalette.pin)
                .shadow(color: Theme.scrim, radius: 1)
                .offset(x: 6, y: -4)
            Circle()
                .strokeBorder(isSet ? Theme.gold : MapPalette.markerRing, lineWidth: 2)
                .frame(width: 10, height: 10)
        }
        .frame(width: MapStyleConfig.pinSize + 12, height: MapStyleConfig.pinSize + 12)
        .scaleEffect(editing ? 1.25 : 1)
        .animation(Motion.snappy, value: editing)
        .contentShape(Rectangle())
        .accessibilityLabel(isSet ? "旗桿位置（已設定）" : "果嶺中心")
    }
}
