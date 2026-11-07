import GolfKit
import SwiftUI

/// Pick a card template, preview it and share (LINE / IG / Photos through the system sheet).
struct ScorecardShareView: View {
    let round: RoundState
    let course: Course?
    let courseName: String
    var events: [RoundEvent] = []

    @Environment(SettingsService.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var template: ShareCardTemplate = .story
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("樣式", selection: $template) {
                    ForEach(ShareCardTemplate.allCases) { Text(LocalizedStringKey($0.title)).tag($0) }
                }
                .pickerStyle(.segmented)
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
                            .shadow(color: Theme.scrim, radius: 16, y: 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            .accessibilityLabel("成績卡預覽，總桿 \(round.totalStrokes)")
                    } else {
                        ProgressView().tint(Theme.gold).frame(maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
                if let image {
                    let shared = Image(uiImage: image)
                    ShareLink(item: shared, preview: SharePreview(Text(verbatim: courseName), image: shared)) {
                        Label("分享成績卡", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(GoldButtonStyle())
                }
                if !events.isEmpty, let roundCourseId = round.courseId {
                    RoundExportButton(events: events, course: course, courseId: roundCourseId, courseName: courseName)
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(Theme.gutter)
            .background(PremiumBackground())
            .navigationTitle("分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .task(id: template) {
                withAnimation(Motion.fade) {
                    image = ShareCardRenderer.render(template, round: round, course: course, courseName: courseName,
                                                     settings: settings.settings)
                }
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }
}
