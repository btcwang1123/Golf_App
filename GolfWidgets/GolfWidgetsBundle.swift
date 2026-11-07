import SwiftUI
import WidgetKit

@main
struct GolfWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RoundLiveActivity()
        HomeStatsWidget()
    }
}

/// Brand colors for the extension (mirrors the app Theme).
enum WidgetPalette {
    static let background = Color(red: 0.039, green: 0.071, blue: 0.055)
    static let gold = Color(red: 0.839, green: 0.725, blue: 0.486)
    static let ivory = Color(red: 0.953, green: 0.937, blue: 0.894)
    static let secondary = ivory.opacity(0.6)
}
