import GolfKit
import SwiftUI

/// Preview of an opened `.golfcourse` file; imports it as a user course.
struct CourseImportView: View {
    let package: CoursePackage

    @Environment(CourseRepository.self) private var courses
    @Environment(\.dismiss) private var dismiss
    @State private var confirmOverwrite = false
    @State private var imported = false

    private var course: Course { package.course }
    private var quality: CourseQuality { CourseQuality.evaluate(course) }
    private var exists: Bool { courses.isUserCourse(id: course.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow("匯入球場資料")
                    Text(verbatim: course.name)
                        .font(Theme.display(30))
                        .foregroundStyle(Theme.ivory)
                    HStack(spacing: 8) {
                        QualityTag(level: quality.level)
                        if course.effectiveProvenance == .survey { Tag(text: "實地踩點", color: Theme.fairway) }
                    }
                    if let hole = course.holes.first(where: { HoleQuality.evaluate($0).isPlayable }) {
                        HoleThumbnail(hole: hole, course: course)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    }
                    HStack(spacing: 12) {
                        StatTile(title: "洞數", value: "\(course.holes.count)")
                        StatTile(title: "完整度", value: "\(Int((quality.score * 100).rounded()))", unit: "%")
                    }
                    Text("匯出於 \(package.exportedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                    Button(imported ? "已匯入" : "匯入為我的球場") {
                        if exists { confirmOverwrite = true } else { save() }
                    }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(imported)
                }
                .padding(Theme.gutter)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } }
            }
            .confirmationDialog("已有同一座球場", isPresented: $confirmOverwrite, titleVisibility: .visible) {
                Button("覆蓋現有資料", role: .destructive) { save() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("匯入會取代你本機的版本。")
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }

    private func save() {
        var c = course
        c.source = .user
        courses.save(userCourse: c)
        imported = true
        Haptics.play(.birdie)
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            dismiss()
        }
    }
}
