import GolfKit
import SwiftUI

struct HoleEditorView: View {
    @Bindable var model: EditorModel

    private static let parRange = 3...6
    private static let handicapRange = 0...18

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("洞", selection: Binding(
                    get: { model.currentHoleNumber },
                    set: { model.selectHole($0) })
                ) {
                    ForEach(model.course.holes, id: \.number) { h in
                        let ok = HoleQuality.evaluate(h).isComplete
                        Text("第\(h.number)洞\(ok ? " ✓" : "")").tag(h.number)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                Stepper("PAR \(model.currentHole?.par ?? EditorModel.defaultPar)",
                        value: Binding(
                            get: { model.currentHole?.par ?? EditorModel.defaultPar },
                            set: { model.setPar($0) }),
                        in: Self.parRange)
                    .fixedSize()
                Menu {
                    Picker("難度", selection: Binding(
                        get: { model.currentHole?.handicap ?? 0 },
                        set: { model.setHandicap($0 == 0 ? nil : $0) })
                    ) {
                        Text("未設定").tag(0)
                        ForEach(1...18, id: \.self) { Text("HCP \($0)").tag($0) }
                    }
                    Divider()
                    Menu("從其他洞複製圖形") {
                        ForEach(model.course.holes.filter { $0.number != model.currentHoleNumber && !$0.features.isEmpty }, id: \.number) { h in
                            Button("第 \(h.number) 洞") { model.copyFeatures(fromHole: h.number) }
                        }
                    }
                    Button("撤銷", systemImage: "arrow.uturn.backward") { model.undo() }
                        .disabled(!model.canUndo)
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
                .accessibilityLabel("更多")
            }

            EditorChecklistView(model: model)

            Picker("工具", selection: $model.tool) {
                ForEach(EditorModel.Tool.allCases) { Text(LocalizedStringKey($0.title)).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.tool == .greenCenter || model.tool == .tee {
                autoLayoutHint
            }

            if model.tool.isPolygon {
                HStack {
                    Text("已描 \(model.draftPolygon.count) 點").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button("取消") { model.cancelDraft() }
                        .disabled(model.draftPolygon.isEmpty)
                    Button("退一點") { model.removeLastDraftPoint() }
                        .disabled(model.draftPolygon.isEmpty)
                    Button("閉合") { model.closePolygon() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.draftPolygon.count < EditorModel.minPolygonPoints)
                }
                .buttonStyle(.bordered)
            } else if model.tool == .edit {
                Text(model.selectedFeature == nil ? "點一個圖形開始調整；拖曳頂點移動，點「+」插入新點，長按頂點刪除。" : "拖曳頂點移動，點「+」插入新點，長按頂點刪除。")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if let features = model.currentHole?.features, !features.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(features.enumerated()), id: \.offset) { index, f in
                                HStack(spacing: 4) {
                                    Circle().fill(MapPalette.fill(for: f.kind)).frame(width: 8, height: 8)
                                    Text(LocalizedStringKey(Self.name(f.kind))).font(.footnote)
                                    Button("刪除", systemImage: "trash") { model.deleteFeature(at: index) }
                                        .labelStyle(.iconOnly)
                                        .font(.footnote)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(model.selectedFeature == index ? AnyShapeStyle(Theme.gold.opacity(0.25)) : AnyShapeStyle(.thinMaterial), in: Capsule())
                                .onTapGesture { model.tool = .edit; model.selectedFeature = index }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                if let next = model.nextIncompleteHole {
                    Button("下一個缺資料的洞", systemImage: "arrow.right.circle") { model.selectHole(next) }
                        .font(.footnote)
                        .buttonStyle(.bordered)
                        .accessibilityHint("前往第 \(next) 洞")
                }
            }
        }
        .padding(.horizontal)
    }

    private var autoLayoutHint: some View {
        Group {
            switch model.lastAutoLayout {
            case .placed(let hole, let meters, let par)?:
                Text("第 \(hole) 洞：依球道推算約 \(Int(meters.rounded())) 公尺、PAR \(par)。發球台位置不對可切到「發球台」點正確位置。")
            case .needsTee(let hole)?:
                Text("第 \(hole) 洞附近找不到球道，請點一下發球台位置。")
                    .foregroundStyle(Theme.gold)
            case nil:
                Text(model.tool == .greenCenter
                     ? "在每一洞的果嶺中心點一下，系統會依球道推算發球台、距離與 PAR，並跳到下一洞。"
                     : "點一下發球台位置。")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func name(_ kind: Feature.Kind) -> String {
        switch kind {
        case .fairway: "球道"
        case .green: "果嶺"
        case .tee: "發球台"
        case .bunker: "沙坑"
        case .water: "水"
        case .lateralWater: "側水"
        case .rough: "長草"
        case .outOfBounds: "OB"
        }
    }
}
