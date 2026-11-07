import SwiftUI
import UIKit

/// App-wide palette, type scale and metrics. Dark "clubhouse" look: deep forest green + champagne gold.
enum Theme {
    // MARK: Colors

    static let background = Color(hex: 0x0A120E)
    static let backgroundTop = Color(hex: 0x14261D)
    static let surface = Color(hex: 0x111C17)
    static let surfaceRaised = Color(hex: 0x182720)
    static let hairline = Color.white.opacity(0.08)

    static let gold = Color(hex: 0xD6B97C)
    static let goldDeep = Color(hex: 0xA7854A)
    static let fairway = Color(hex: 0x4E9A72)

    static let ivory = Color(hex: 0xF3EFE4)
    static let textSecondary = Color(hex: 0xF3EFE4).opacity(0.58)
    static let textTertiary = Color(hex: 0xF3EFE4).opacity(0.34)

    static let eagle = Color(hex: 0xE7C35E)
    static let birdie = Color(hex: 0xDE7A5F)
    static let bogey = Color(hex: 0x7EA6CF)
    static let doubleBogey = Color(hex: 0x56789F)
    static let danger = Color(hex: 0xD9625A)
    static let warning = Color(hex: 0xE3A857)
    /// Text / icons drawn on gold fills.
    static let onGold = Color(hex: 0x1A140A)
    /// Light surface used by share cards on light backgrounds.
    static let paper = Color(hex: 0xF7F3EA)
    static let ink = Color(hex: 0x14201A)
    static let skeleton = Color.white.opacity(0.06)
    static let scrim = Color.black.opacity(0.45)

    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xE9D3A0), gold, goldDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x1F3A2C), Color(hex: 0x0F1C16)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: Metrics

    static let corner: CGFloat = 22
    static let cornerSmall: CGFloat = 14
    static let gutter: CGFloat = 20
    static let cornerTiny: CGFloat = 8
    static let hairlineWidth: CGFloat = 1
    static let iconButton: CGFloat = 40
    static let tapTarget: CGFloat = 44

    // MARK: Type

    /// Elegant serif for titles (New York).
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Light, wide numerals for scores and distances.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }

    /// Small tracked caps label.
    static let eyebrow = Font.system(size: 11, weight: .semibold)

    // MARK: UIKit appearance

    @MainActor static func configureAppearance() {
        let ivory = UIColor(Theme.ivory)
        let large = UIFont.systemFont(ofSize: 34, weight: .semibold)
        let inline = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let serifLarge = large.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 34) } ?? large
        let serifInline = inline.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 17) } ?? inline

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.largeTitleTextAttributes = [.font: serifLarge, .foregroundColor: ivory]
        nav.titleTextAttributes = [.font: serifInline, .foregroundColor: ivory]
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        scrolled.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.6)
        scrolled.largeTitleTextAttributes = nav.largeTitleTextAttributes
        scrolled.titleTextAttributes = nav.titleTextAttributes
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.75)
        tab.shadowColor = UIColor.white.withAlphaComponent(0.06)
        let item = tab.stackedLayoutAppearance
        item.normal.iconColor = UIColor(Theme.textTertiary)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.textTertiary)]
        item.selected.iconColor = UIColor(Theme.gold)
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.gold)]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}

extension Theme {
    /// Map feature colors (`GolfKit.MapColors`) as SwiftUI colors.
    static func mapColor(_ hex: UInt32, opacity: Double = 1) -> Color { Color(hex: hex, opacity: opacity) }
}

// MARK: - Score styling

enum ScoreTone {
    case eagle, birdie, par, bogey, double, none

    init(strokes: Int?, par: Int?) {
        guard let strokes, strokes > 0, let par else { self = .none; return }
        switch strokes - par {
        case ...(-2): self = .eagle
        case -1: self = .birdie
        case 0: self = .par
        case 1: self = .bogey
        default: self = .double
        }
    }

    var color: Color {
        switch self {
        case .eagle: Theme.eagle
        case .birdie: Theme.birdie
        case .par: Theme.ivory
        case .bogey: Theme.bogey
        case .double: Theme.doubleBogey
        case .none: Theme.textTertiary
        }
    }

    var label: String {
        switch self {
        case .eagle: "老鷹"
        case .birdie: "博蒂"
        case .par: "平標準"
        case .bogey: "柏忌"
        case .double: "雙柏忌+"
        case .none: ""
        }
    }
}
