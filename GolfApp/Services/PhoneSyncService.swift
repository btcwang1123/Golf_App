import Foundation
import GolfKit
import Observation
import OSLog
import WatchConnectivity

@MainActor @Observable
final class PhoneSyncService: NSObject, WCSessionDelegate {
    private(set) var isReachable = false
    private(set) var isPaired = false
    /// Bumped whenever a calibration file lands in `calibrationDirectory`.
    private(set) var calibrationFilesVersion = 0

    @ObservationIgnored private let roundStore: RoundStore
    @ObservationIgnored private let courses: CourseRepository
    @ObservationIgnored private let settings: SettingsService
    @ObservationIgnored private var pending: [SyncMessage] = []
    /// A range session arrived from the watch.
    @ObservationIgnored var onPractice: ((PracticeSession) -> Void)?
    @ObservationIgnored private let log = Logger(subsystem: "GolfApp", category: "PhoneSync")
    @ObservationIgnored private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    nonisolated static var calibrationDirectory: URL {
        URL.documentsDirectory.appending(path: "Calibration", directoryHint: .isDirectory)
    }

    init(roundStore: RoundStore, courses: CourseRepository, settings: SettingsService) {
        self.roundStore = roundStore
        self.courses = courses
        self.settings = settings
        super.init()
        roundStore.onEventsAppended = { [weak self] events in self?.handleLocalEvents(events) }
        settings.onChange = { [weak self] new in self?.send(.settings(new)) }
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: Sending

    /// - Parameter ordered: always use the FIFO `transferUserInfo` queue so the message
    ///   cannot overtake earlier queued messages (e.g. `.startRound`).
    func send(_ msg: SyncMessage, ordered: Bool = false) {
        guard let session, session.activationState == .activated else {
            pending.append(msg)
            return
        }
        guard let dict = try? msg.encodedDictionary(),
              let data = try? msg.encoded() else { return }
        if case .course = msg {
            session.transferUserInfo(dict)
            return
        }
        if case .startRound = msg {
            session.transferUserInfo(dict)
            return
        }
        if session.isReachable, !ordered {
            session.sendMessage(dict, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo([SyncMessage.payloadKey: data])
            }
        } else {
            session.transferUserInfo(dict)
        }
    }

    private func handleLocalEvents(_ events: [RoundEvent]) {
        var startsRound = false
        for e in events where e.source == .phone {
            if case .start(let courseId) = e.kind {
                startsRound = true
                if let course = courses.course(id: courseId) { send(.course(course)) }
                send(.startRound(roundId: e.roundId, courseId: courseId))
            }
            if case .end = e.kind {
                send(.endRound(roundId: e.roundId))
            }
        }
        send(.events(events), ordered: startsRound)
    }

    private func flush() {
        guard let session, session.activationState == .activated else { return }
        isReachable = session.isReachable
        isPaired = session.isPaired
        let queued = pending
        pending = []
        queued.forEach { send($0) }
        send(.settings(settings.settings))
        if session.isReachable, !roundStore.events.isEmpty {
            send(.events(roundStore.events))
        }
    }

    // MARK: Receiving

    private func handle(_ msg: SyncMessage) {
        switch msg {
        case .events(let events):
            roundStore.merge(events)
        case .startRound(let roundId, let courseId):
            roundStore.adopt(roundId: roundId, courseId: courseId)
        case .course(let course):
            if courses.course(id: course.id) == nil { courses.save(userCourse: course) }
        case .settings(let new):
            settings.applyRemote(new)
        case .endRound(let roundId):
            let isOpen = roundStore.active?.roundId == roundId
                || roundStore.record(id: roundId)?.endedAt == nil
            if isOpen {
                roundStore.merge([RoundEvent.make(roundId: roundId, source: .watch, kind: .end)])
            }
        case .requestCourse(let courseId):
            if let course = courses.course(id: courseId) { send(.course(course)) }
        case .practice(let session):
            onPractice?(session)
        }
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.flush() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.flush() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.flush() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        decodeAndHandle(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        decodeAndHandle(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let fm = FileManager.default
        let dir = Self.calibrationDirectory
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            var dest = dir.appending(path: file.fileURL.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                let stamp = Int(Date().timeIntervalSince1970)
                dest = dir.appending(path: "\(stamp)-\(file.fileURL.lastPathComponent)")
            }
            try fm.moveItem(at: file.fileURL, to: dest)
        } catch {
            return
        }
        Task { @MainActor in self.calibrationFilesVersion += 1 }
    }

    private nonisolated func decodeAndHandle(_ dict: [String: Any]) {
        guard let msg = try? SyncMessage.decode(from: dict) else { return }
        Task { @MainActor in self.handle(msg) }
    }
}
