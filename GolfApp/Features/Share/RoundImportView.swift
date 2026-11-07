import GolfKit
import SwiftUI

/// Opened `.golfround`: choose "which one is me", then save that player's view as a new round.
struct RoundImportView: View {
    let export: RoundExport

    @Environment(RoundStore.self) private var roundStore
    @Environment(CourseRepository.self) private var courses
    @Environment(\.dismiss) private var dismiss
    @State private var viewer: UUID?
    @State private var result: String?

    private var course: Course? { courses.course(id: export.courseId) }
    private var state: RoundState { RoundReducer.reduce(export.events, course: course) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow("同組回合")
                    Text(verbatim: course?.name ?? export.courseName)
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.ivory)
                    if let d = state.startedAt {
                        Text(d.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    SectionTitle(title: "我是哪一位？")
                    VStack(spacing: 8) {
                        ForEach(state.players) { p in
                            Button {
                                viewer = p.id
                                Haptics.play(.selection)
                            } label: {
                                HStack {
                                    Image(systemName: viewer == p.id ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(Theme.gold)
                                    Text(verbatim: p.name).foregroundStyle(Theme.ivory)
                                    Spacer()
                                    Text(verbatim: "\(state.total(for: p.id))").font(Theme.numeral(18)).foregroundStyle(Theme.ivory)
                                    Text(ScoreFormat.toPar(state.toPar(for: p.id))).font(.caption.weight(.semibold)).foregroundStyle(Theme.gold)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(viewer == p.id ? Theme.surfaceRaised : Theme.surface))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if course == nil {
                        Text("本機沒有這座球場，將以「\(export.courseName)」顯示。")
                            .font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                    if let result {
                        Text(result).font(.footnote).foregroundStyle(Theme.fairway)
                    }
                    Button("存進我的紀錄") { save() }
                        .buttonStyle(GoldButtonStyle())
                        .disabled(viewer == nil || result != nil)
                }
                .padding(Theme.gutter)
            }
            .background(PremiumBackground())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } } }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let viewer else { return }
        do {
            let events = try export.eventsForViewer(viewer, course: course)
            if roundStore.importRound(events: events, courseId: export.courseId, courseName: course?.name ?? export.courseName) != nil {
                result = String(localized: "已存進紀錄")
                Haptics.play(.birdie)
            } else {
                result = String(localized: "這場已經匯入過了")
            }
        } catch {
            result = error.localizedDescription
        }
    }
}
