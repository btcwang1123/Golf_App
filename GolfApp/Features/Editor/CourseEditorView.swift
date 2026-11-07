import GolfKit
import SwiftUI

struct CourseEditorView: View {
    let course: Course?

    @Environment(CourseRepository.self) private var repository
    @Environment(LocationService.self) private var location
    @Environment(SettingsService.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var model: EditorModel?
    @State private var survey: SurveyModel?
    @State private var surveying = false
    @State private var name = ""
    @State private var holeCount = 18

    private static let taiwanCenter = GeoPoint(lat: 23.7, lon: 121.0)
    private static let holeCounts = [9, 18]

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    editor(model)
                } else {
                    setupForm
                }
            }
            .navigationTitle(model?.course.name ?? course?.name ?? String(localized: "新增球場"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                if let model {
                    ToolbarItem(placement: .principal) {
                        Text("完成度 \(Int((model.completion * 100).rounded()))%")
                            .font(Theme.numeral(13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .contentTransition(.numericText())
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("儲存") {
                            repository.save(userCourse: model.finalizedCourse())
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            if model == nil, let course, !course.holes.isEmpty {
                model = EditorModel(course: course, isNew: false)
            }
        }
        .onDisappear { survey?.deactivate() }
    }

    private var setupForm: some View {
        Form {
            Section("球場資料") {
                if let course {
                    Text(verbatim: course.name)
                } else {
                    TextField("球場名稱", text: $name)
                }
                Picker("洞數", selection: $holeCount) {
                    ForEach(Self.holeCounts, id: \.self) { Text("\($0) 洞").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Button("開始描繪") {
                    if let course {
                        model = EditorModel(course: EditorModel.withHoles(course, count: holeCount), isNew: false)
                        return
                    }
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let center = location.current ?? Self.taiwanCenter
                    model = EditorModel(
                        course: EditorModel.newCourse(name: trimmed, holeCount: holeCount, center: center),
                        isNew: true)
                }
                .disabled(course == nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text(course == nil ? "描繪的資料只存在本機，不會上傳。" : "這座球場還沒有分洞資料。選好洞數後，在每一洞的果嶺中心點一下即可。")
            }
        }
    }

    private func editor(_ model: EditorModel) -> some View {
        VStack(spacing: 8) {
            HoleEditorView(model: model)
            Toggle(isOn: Binding(get: { surveying }, set: { setSurveying($0, model: model) })) {
                Label("實地踩點模式", systemImage: "location.viewfinder")
            }
            .padding(.horizontal)
            .tint(Theme.gold)
            if surveying, let survey {
                SurveyModeView(survey: survey, settings: settings.settings)
            }
            PolygonDrawingView(model: model)
            Text(surveying ? "踩點資料可分享或收錄為精選球場；在衛星圖上手繪的資料只存在本機。" : "描繪的資料只存在本機，不會上傳。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: model.currentHoleNumber) { survey?.holeChanged() }
    }

    private func setSurveying(_ on: Bool, model: EditorModel) {
        surveying = on
        if on {
            let s = survey ?? SurveyModel(editor: model, location: location)
            survey = s
            s.activate()
        } else {
            survey?.deactivate()
        }
    }
}
