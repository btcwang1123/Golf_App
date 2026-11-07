import GolfKit
import SwiftUI

struct RootView: View {
    /// UI tests launch straight into the showcase for App Store screenshots.
    static let uiTestShowcaseArgument = "-UITestShowcase"
    /// UI tests that navigate the tabs skip onboarding.
    static let uiTestSkipOnboardingArgument = "-UITestSkipOnboarding"

    @Environment(AppRouter.self) private var router
    @Environment(SettingsService.self) private var settings
    @Environment(DiagnosticsService.self) private var diagnostics

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("首頁", systemImage: "house.fill") }
                .tag(AppRouter.Tab.home)
            CourseListView()
                .tabItem { Label("球場", systemImage: "flag.fill") }
                .tag(AppRouter.Tab.courses)
            HistoryListView()
                .tabItem { Label("歷史", systemImage: "list.bullet.rectangle.portrait") }
                .tag(AppRouter.Tab.history)
            InsightsView()
                .tabItem { Label("統計", systemImage: "chart.xyaxis.line") }
                .tag(AppRouter.Tab.insights)
            SettingsView()
                .tabItem { Label("設定", systemImage: "slider.horizontal.3") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains(Self.uiTestShowcaseArgument) {
                settings.settings.onboardingCompleted = true
                router.showShowcase = true
            } else if ProcessInfo.processInfo.arguments.contains(Self.uiTestSkipOnboardingArgument) {
                settings.settings.onboardingCompleted = true
            } else if !settings.settings.onboardingCompleted {
                router.showOnboarding = true
            }
            diagnostics.markInteractive()
        }
        .fullScreenCover(isPresented: $router.showOnboarding) { OnboardingView() }
        .fullScreenCover(isPresented: $router.showShowcase) { ShowcaseView() }
        .fullScreenCover(isPresented: $router.showRound) { RoundView() }
        .sheet(item: $router.pendingImport) { item in
            switch item {
            case .course(let pkg): CourseImportView(package: pkg)
            case .round(let export): RoundImportView(export: export)
            case .failure(let message): ImportErrorView(message: message)
            }
        }
    }
}

/// Shown when an opened file cannot be read.
struct ImportErrorView: View {
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EmptyStateView(icon: "exclamationmark.triangle", title: "無法開啟檔案", message: LocalizedStringKey(message),
                       actionTitle: "好", action: { dismiss() })
            .background(PremiumBackground())
            .presentationDetents([.medium])
            .preferredColorScheme(.dark)
    }
}
