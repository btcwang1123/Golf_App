import SwiftUI
import GolfKit

@main
struct GolfWatchApp: App {
    @State private var settings: WatchSettingsService
    @State private var location: WatchLocationService
    @State private var workout: WorkoutService
    @State private var store: WatchRoundStore
    @State private var sync: WatchSyncService
    @State private var recorder: MotionRecorder
    @State private var practice: WatchPracticeStore

    init() {
        let settings = WatchSettingsService()
        let location = WatchLocationService()
        let workout = WorkoutService()
        let monitor = SwingMonitor(motion: MotionService(), location: location)
        let store = WatchRoundStore(settings: settings, location: location, workout: workout, monitor: monitor)
        let sync = WatchSyncService(store: store, settings: settings)
        let recorder = MotionRecorder(settings: settings)
        let practice = WatchPracticeStore(monitor: monitor, workout: workout, settings: settings)
        practice.onFinished = { [sync] session in sync.send(.practice(session)) }
        WatchIntentBridge.shared.store = store
        settings.onChange = { [monitor] new in monitor.apply(settings: new) }
        recorder.onFinished = { [sync] url in sync.transferCalibration(fileURL: url) }
        sync.activate()
        if ProcessInfo.processInfo.arguments.contains("-UITestDemo") {
            store.start(course: WatchDemoCourse.make())
        }

        _settings = State(initialValue: settings)
        _location = State(initialValue: location)
        _workout = State(initialValue: workout)
        _store = State(initialValue: store)
        _sync = State(initialValue: sync)
        _recorder = State(initialValue: recorder)
        _practice = State(initialValue: practice)
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(settings)
                .environment(location)
                .environment(workout)
                .environment(store)
                .environment(sync)
                .environment(recorder)
                .environment(practice)
        }
    }
}
