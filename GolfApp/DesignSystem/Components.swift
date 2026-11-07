import GolfKit
import SwiftUI

// MARK: - Background

/// Full-bleed deep green background with a soft glow at the top.
struct PremiumBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.backgroundTop.opacity(0.9), .clear],
                center: .init(x: 0.2, y: -0.05), startRadius: 10, endRadius: 520)
            RadialGradient(
                colors: [Theme.gold.opacity(0.07), .clear],
                center: .init(x: 1.0, y: 0.0), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the premium background behind a scroll view / list.
    func premiumBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(PremiumBackground())
    }

    /// Surface card with hairline border.
    func card(padding: CGFloat = 18, corner: CGFloat = Theme.corner, raised: Bool = false) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(raised ? Theme.surfaceRaised : Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1))
    }

    /// Row styling for themed `List` / `Form` rows.
    func themedRow() -> some View {
        listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.hairline)
    }
}

// MARK: - Text

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.gold

    init(_ text: String, color: Color = Theme.gold) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(Theme.eyebrow)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(title))
                .font(Theme.display(22, weight: .medium))
                .accessibilityAddTraits(.isHeader)
                .foregroundStyle(Theme.ivory)
            Spacer()
            if let trailing {
                Text(LocalizedStringKey(trailing))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let title: String
    let value: String
    var unit: String?
    var accent: Color = Theme.ivory

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(title, color: Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.numeral(28))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(LocalizedStringKey(unit))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16, corner: Theme.cornerSmall + 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

struct GoldButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 17, weight: .semibold))
            .foregroundStyle(Theme.onGold)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 56)
            .background(
                Capsule().fill(Theme.goldGradient)
                    .shadow(color: Theme.gold.opacity(configuration.isPressed ? 0.1 : 0.28), radius: 18, y: 8))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var compact = false
    var tint: Color = Theme.ivory

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 16, weight: .medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 54)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.05)))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Round icon button used in compact toolbars.
struct CircleIconButtonStyle: ButtonStyle {
    var size: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ivory)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07)))
            .overlay(Circle().strokeBorder(Theme.hairline))
    }
}

// MARK: - Score mark

/// Traditional scorecard notation: circles under par, squares over par.
struct ScoreMark: View {
    let strokes: Int?
    let par: Int?
    var size: CGFloat = 30

    private var tone: ScoreTone { ScoreTone(strokes: strokes, par: par) }

    var body: some View {
        ZStack {
            switch tone {
            case .eagle:
                Circle().strokeBorder(tone.color, lineWidth: 1.2)
                Circle().strokeBorder(tone.color, lineWidth: 1.2).padding(3)
            case .birdie:
                Circle().strokeBorder(tone.color, lineWidth: 1.2)
            case .bogey:
                RoundedRectangle(cornerRadius: 4).strokeBorder(tone.color, lineWidth: 1.2)
            case .double:
                RoundedRectangle(cornerRadius: 4).fill(tone.color.opacity(0.25))
                RoundedRectangle(cornerRadius: 4).strokeBorder(tone.color, lineWidth: 1.2)
            case .par, .none:
                EmptyView()
            }
            Text(strokes.map(String.init) ?? "–")
                .font(Theme.numeral(size * 0.5, weight: .regular))
                .foregroundStyle(tone == .none ? Theme.textTertiary : Theme.ivory)
        }
        .frame(width: size, height: size)
    }
}

/// Large ring showing a round's total vs par.
struct ScoreRing: View {
    let total: Int?
    let toPar: Int?
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle().fill(Theme.surfaceRaised)
            Circle().strokeBorder(Theme.goldGradient, lineWidth: 1.2)
            VStack(spacing: 0) {
                Text(total.map(String.init) ?? "—")
                    .font(Theme.numeral(size * 0.36, weight: .regular))
                    .foregroundStyle(Theme.ivory)
                Text(ScoreFormat.toPar(toPar))
                    .font(.system(size: size * 0.17, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Small capsule tag.
struct Tag: View {
    let text: String
    var color: Color = Theme.gold

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 0.5))
    }
}

/// Stepper with large numerals, used for manual score entry.
struct ValueStepper: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var emphasized = false

    var body: some View {
        VStack(spacing: 8) {
            Eyebrow(title, color: Theme.textSecondary)
            HStack(spacing: 14) {
                stepButton("minus", enabled: value > range.lowerBound) { value -= 1 }
                Text("\(value)")
                    .font(Theme.numeral(emphasized ? 44 : 30, weight: emphasized ? .light : .regular))
                    .foregroundStyle(emphasized ? Theme.ivory : Theme.ivory.opacity(0.9))
                    .frame(minWidth: emphasized ? 56 : 36)
                    .contentTransition(.numericText(value: Double(value)))
                stepButton("plus", enabled: value < range.upperBound) { value += 1 }
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: value)
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(CircleIconButtonStyle(size: 38))
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
    }
}

// MARK: - Course quality

extension CourseQuality.Level {
    var tint: Color {
        switch self {
        case .full: Theme.fairway
        case .partial: Theme.gold
        case .scoreOnly: Theme.textSecondary
        }
    }
}

struct QualityTag: View {
    let level: CourseQuality.Level
    var body: some View { Tag(text: level.label, color: level.tint) }
}

struct FeaturedBadge: View {
    var body: some View {
        Label("精選", systemImage: "star.fill")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10.5, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(Theme.onGold)
            .background(Capsule().fill(Theme.goldGradient))
            .accessibilityLabel("精選球場")
    }
}
