import Foundation
import GolfKit
import WatchConnectivity

/// WCSession wrapper for the watch side.
@MainActor @Observable
final class WatchSyncService: NSObject, WCSessionDelegate {
    private(set) var isReachable = false
    private(set) var isActivated = false

    @ObservationIgnored private let store: WatchRoundStore
    @ObservationIgnored private let settings: WatchSettingsService
    @ObservationIgnored private let session: WCSession?

    init(store: WatchRoundStore, settings: WatchSettingsService) {
        self.store = store
        self.settings = settings
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()

        store.onEventsAppended = { [weak self] events in self?.send(.events(events)) }
        store.onRoundStarted = { [weak self] roundId, courseId in
            self?.send(.startRound(roundId: roundId, courseId: courseId))
        }
        store.onCourseNeeded = { [weak self] courseId in self?.send(.requestCourse(courseId: courseId)) }
        settings.onLocalEdit = { [weak self] new in self?.send(.settings(new)) }
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends immediately when reachable, otherwise queues with `transferUserInfo`.
    func send(_ message: SyncMessage) {
        guard let session, let dict = try? message.encodedDictionary() else { return }
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { [weak self] _ in
                Task { @MainActor in self?.queue(message) }
            }
        } else {
            _ = session.transferUserInfo(dict)
        }
    }

    private func queue(_ message: SyncMessage) {
        guard let session, let dict = try? message.encodedDictionary() else { return }
        _ = session.transferUserInfo(dict)
    }

    /// Sends a recorded CSV to the phone.
    func transferCalibration(fileURL: URL) {
        guard let session else { return }
        _ = session.transferFile(fileURL, metadata: ["kind": "calibration"])
    }

    // MARK: - Incoming

    private func handle(_ message: SyncMessage) {
        switch message {
        case .course(let course):
            store.cacheCourse(course)
        case .startRound(let roundId, let courseId):
            store.adopt(roundId: roundId, courseId: courseId)
        case .events(let events):
            store.merge(events)
        case .settings(let new):
            settings.apply(new)
        case .endRound(let roundId):
            if store.roundId == roundId { store.end() }
        case .requestCourse, .practice:
            break
        }
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {
        let activated = activationState == .activated
        let reachable = session.isReachable
        Task { @MainActor in
            self.isActivated = activated
            self.isReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let decoded = try? SyncMessage.decode(from: message) else { return }
        Task { @MainActor in self.handle(decoded) }
    }

    nonisolated func session(
        _ session: WCSession, didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let decoded = try? SyncMessage.decode(from: message) else { return replyHandler([:]) }
        Task { @MainActor in self.handle(decoded) }
        replyHandler([:])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let decoded = try? SyncMessage.decode(from: userInfo) else { return }
        Task { @MainActor in self.handle(decoded) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let decoded = try? SyncMessage.decode(from: applicationContext) else { return }
        Task { @MainActor in self.handle(decoded) }
    }
}
