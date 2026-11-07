@preconcurrency import HealthKit
import Foundation

/// Runs an outdoor golf `HKWorkoutSession` so the app keeps sampling with the screen off.
@MainActor @Observable
final class WorkoutService: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private(set) var isRunning = false
    private(set) var heartRate: Double?
    /// Human readable explanation when HealthKit is unavailable / denied.
    private(set) var authorizationDenied: String?

    @ObservationIgnored private let healthStore = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?

    private var shareTypes: Set<HKSampleType> { [HKObjectType.workoutType()] }
    private var readTypes: Set<HKObjectType> {
        guard let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        return [hr]
    }

    func start() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationDenied = "此裝置無法使用健康資料，仍可手動記桿。"
            return
        }
        guard !isRunning else { return }
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            authorizationDenied = "未取得健康權限，螢幕熄滅後可能無法偵測揮桿；仍可手動記桿。"
            return
        }
        if healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingDenied {
            authorizationDenied = "未允許體能訓練權限，螢幕熄滅後可能無法偵測揮桿；仍可手動記桿。"
            return
        }
        authorizationDenied = nil

        let config = HKWorkoutConfiguration()
        config.activityType = .golf
        config.locationType = .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let date = Date()
            session.startActivity(with: date)
            try await builder.beginCollection(at: date)
            isRunning = true
        } catch {
            authorizationDenied = "無法啟動體能訓練，仍可手動記桿。"
            session = nil
            builder = nil
        }
    }

    /// Ends the session and saves the workout to Health.
    func end() async {
        guard let session, let builder else { return }
        self.session = nil
        self.builder = nil
        isRunning = false
        heartRate = nil
        session.end()
        do {
            try await builder.endCollection(at: Date())
            _ = try await builder.finishWorkout()
        } catch {
            // Saving failed (e.g. permission revoked); nothing more to do.
        }
    }

    // MARK: - HKWorkoutSessionDelegate

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        let running = toState == .running
        Task { @MainActor in
            if self.session != nil { self.isRunning = running }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.isRunning = false }
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(type) else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = workoutBuilder.statistics(for: type)?.mostRecentQuantity()?.doubleValue(for: unit)
        Task { @MainActor in self.heartRate = bpm }
    }
}
