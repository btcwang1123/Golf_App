import GolfKit
import SwiftUI

/// First launch: three value pages, then units / wrist / home course.
struct OnboardingView: View {
    @Environment(SettingsService.self) private var settings
    @Environment(CourseRepository.self) private var courses
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var courseQuery = ""

    private static let pageCount = 4

    var body: some View {
        @Bindable var service = settings
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < Self.pageCount - 1 {
                    Button("略過") { withAnimation(Motion.standard) { page = Self.pageCount - 1 } }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .frame(height: Theme.tapTarget)

            TabView(selection: $page) {
                OnboardingPage(art: .watch, title: "手錶揮桿自動記桿",
                               message: "戴上 Apple Watch 打球，每次揮桿自動 +1，推桿再手動補一下就好。")
                    .tag(0)
                OnboardingPage(art: .map, title: "全台球場 2.5D 球道圖",
                               message: "到果嶺前、中、後距離與障礙物距離一目了然。\n不用註冊，下載就能用。")
                    .tag(1)
                OnboardingPage(art: .group, title: "和朋友一起記分、分享成績",
                               message: "一人記分，同組四人的成績都在；打完一鍵產生成績卡傳到群組。")
                    .tag(2)
                setupPage(service: service).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 10) {
                Button(page < Self.pageCount - 1 ? "下一步" : "開始使用") {
                    if page < Self.pageCount - 1 {
                        withAnimation(Motion.standard) { page += 1 }
                    } else {
                        finish()
                    }
                }
                .buttonStyle(GoldButtonStyle())
                Button("看展示") {
                    finish()
                    Task {
                        try? await Task.sleep(for: .seconds(0.6))
                        router.showShowcase = true
                    }
                }
                .foregroundStyle(Theme.gold)
                .frame(height: Theme.tapTarget)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 12)
        }
        .background(PremiumBackground())
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }

    private func setupPage(service: SettingsService) -> some View {
        @Bindable var service = service
        let matches = courseQuery.isEmpty ? [] : Array(courses.search(courseQuery).prefix(4))
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("幾個小設定")
                    .font(Theme.display(28, weight: .medium))
                    .foregroundStyle(Theme.ivory)
                    .padding(.top, 20)
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("距離單位", color: Theme.textSecondary)
                    Picker("單位", selection: $service.settings.distanceUnit) {
                        Text("碼").tag(AppSettings.DistanceUnit.yard)
                        Text("公尺").tag(AppSettings.DistanceUnit.meter)
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("手錶戴在", color: Theme.textSecondary)
                    Picker("佩戴手腕", selection: $service.settings.wrist) {
                        Text("左手").tag(AppSettings.Wrist.left)
                        Text("右手").tag(AppSettings.Wrist.right)
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("常去球場（可選）", color: Theme.textSecondary)
                    if let id = service.settings.favoriteCourseId, let c = courses.course(id: id) {
                        HStack {
                            Text(verbatim: c.name).foregroundStyle(Theme.ivory)
                            Spacer()
                            Button("更換") { service.settings.favoriteCourseId = nil }
                        }
                        .card(padding: 14)
                    } else {
                        TextField("搜尋球場", text: $courseQuery)
                            .textFieldStyle(.roundedBorder)
                        ForEach(matches) { c in
                            Button {
                                service.settings.favoriteCourseId = c.id
                                courseQuery = ""
                            } label: {
                                Text(verbatim: c.name).foregroundStyle(Theme.ivory).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                Text("不用註冊，資料都存在你的手機上。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 28)
        }
    }

    private func finish() {
        settings.settings.onboardingCompleted = true
        dismiss()
    }
}
