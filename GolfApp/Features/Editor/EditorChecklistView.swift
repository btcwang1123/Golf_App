import GolfKit
import SwiftUI

/// The current hole's data checklist (T20 items). Tapping a missing item switches to the tool that fixes it.
struct EditorChecklistView: View {
    @Bindable var model: EditorModel

    static func title(_ item: HoleQuality.Item) -> String {
        switch item {
        case .tee: "發球台"
        case .greenCenter: "果嶺中心"
        case .greenPolygon: "果嶺邊界"
        case .par: "標準桿"
        case .fairway: "球道"
        case .hazards: "障礙"
        case .handicap: "難度"
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HoleQuality.Item.allCases, id: \.self) { item in
                    let done = model.checklist[item] ?? false
                    Button {
                        model.focus(on: item)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: done ? "checkmark.circle.fill" : (item.isRequired ? "exclamationmark.circle" : "circle"))
                            Text(LocalizedStringKey(Self.title(item)))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(done ? Theme.fairway : (item.isRequired ? Theme.warning : Theme.textSecondary))
                        .background(Capsule().fill(Theme.surfaceRaised))
                        .overlay(Capsule().strokeBorder(Theme.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Self.title(item))，\(done ? "已完成" : "缺少")")
                }
            }
        }
    }
}
