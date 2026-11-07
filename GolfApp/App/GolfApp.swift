import SwiftData
import SwiftUI

@main
struct GolfApp: App {
    private let container: ModelContainer
    @State private var courses: CourseRepository
    @State private var roundStore: RoundStore
    @State private var location: LocationService
    @State private var settings: SettingsService
    @State private var sync: PhoneSyncService
    @State private var router = AppRouter()
    @State private var recentPlayers = RecentPlayersStore()
    @State private var weather = WeatherService()
    @State private var liveActivity = LiveActivityService()
    @State private var diagnostics = DiagnosticsService()
    @State private var plans: HolePlanStore
    @State private var practice: PracticeStore
    @State private var teeTimes = TeeTimeStore()

    init() {
        Theme.configureAppearance()
        let container = ModelContainer.app()
        let context = container.mainContext
        let courses = CourseRepository(context: context)
        let roundStore = RoundStore(context: context, courses: courses)
        let settings = SettingsService()
        let practice = PracticeStore(context: context)
        let location = LocationService()
        let sync = PhoneSyncService(roundStore: roundStore, courses: courses, settings: settings)
        sync.onPractice = { [practice] in practice.save($0) }
        IntentBridge.shared.roundStore = roundStore
        IntentBridge.shared.location = location
        IntentBridge.shared.settings = settings
        self.container = container
        _courses = State(initialValue: courses)
        _roundStore = State(initialValue: roundStore)
        _location = State(initialValue: location)
        _settings = State(initialValue: settings)
        _sync = State(initialValue: sync)
        _plans = State(initialValue: HolePlanStore(context: context))
        _practice = State(initialValue: practice)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(courses)
                .environment(roundStore)
                .environment(location)
                .environment(settings)
                .environment(sync)
                .environment(router)
                .environment(recentPlayers)
                .environment(weather)
                .environment(liveActivity)
                .environment(diagnostics)
                .environment(plans)
                .environment(practice)
                .environment(teeTimes)
                .onOpenURL { router.open(url: $0) }
                .task {
                    wireLiveActivity()
                    await courses.load()
                    roundStore.courseDidLoad()
                }
        }
        .modelContainer(container)
    }

    /// Mirrors the main round store into the Live Activity (the showcase store is not wired).
    private func wireLiveActivity() {
        let live = liveActivity
        let settings = settings
        let location = location
        let store = roundStore
        roundStore.onActiveChange = { state, course in
            guard let state, !state.isEnded else { live.end(); return }
            let content = LiveActivityService.content(
                round: state, course: course, location: location.current, unit: settings.settings.distanceUnit)
            live.start(courseName: course?.name ?? store.activeCourse?.name ?? "", state: content, roundId: state.roundId)
            live.update(content)
        }
        if let active = roundStore.active {
            roundStore.onActiveChange?(active, roundStore.activeCourse)
        }
    }
}
