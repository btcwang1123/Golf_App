import ActivityKit
import Foundation
import GolfKit
import Observation
import OSLog

/// Lock screen / Dynamic Island activity for the active round.
@MainActor @Observable
final class LiveActivityService {
    @ObservationIgnored private var activity: Activity<RoundActivityAttributes>?
    @ObservationIgnored private var throttle = ActivityUpdateThrottle()
    @ObservationIgnored private var lastState: RoundActivityAttributes.ContentState?
    @ObservationIgnored private var roundId: UUID?
    @ObservationIgnored private let log = Logger(subsystem: "GolfApp", category: "LiveActivity")
    @ObservationIgnored var unit: AppSettings.DistanceUnit = .yard

    private var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(courseName: String, state: RoundActivityAttributes.ContentState, roundId: UUID) {
        guard enabled else { return }
        if self.roundId == roundId, activity != nil { return }
        end()
        do {
            activity = try Activity.request(
                attributes: RoundActivityAttributes(courseName: courseName),
                content: ActivityContent(state: state, staleDate: nil))
            self.roundId = roundId
            lastState = state
            throttle.recordForced(location: nil)
        } catch {
            // User turned Live Activities off or the system refused: not an error for the user.
            log.info("live activity unavailable: \(error.localizedDescription)")
        }
    }

    /// Round state changed (stroke / hole): always pushed.
    func update(_ state: RoundActivityAttributes.ContentState) {
        guard activity != nil, state != lastState else { return }
        throttle.recordForced(location: nil)
        push(state)
    }

    /// Player moved: pushed at most every 5 m and 4×/minute.
    func locationChanged(_ p: GeoPoint, state: RoundActivityAttributes.ContentState) {
        guard activity != nil, state != lastState, throttle.shouldUpdate(location: p) else { return }
        push(state)
    }

    func end() {
        guard let id = activity?.id else { return }
        activity = nil
        roundId = nil
        lastState = nil
        Task {
            for a in Activity<RoundActivityAttributes>.activities where a.id == id {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func push(_ state: RoundActivityAttributes.ContentState) {
        lastState = state
        guard let id = activity?.id else { return }
        Task {
            for a in Activity<RoundActivityAttributes>.activities where a.id == id {
                await a.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    /// Maps the round store's state into the activity payload.
    static func content(round: RoundState, course: Course?, location: GeoPoint?, unit: AppSettings.DistanceUnit) -> RoundActivityAttributes.ContentState {
        let n = round.currentHole
        let hole = course?.hole(n)
        let target = round.pin(for: n) ?? hole?.effectiveGreenCenter
        let d = zip2(location, target).map { Geo.distance($0, $1) }
        return .init(hole: n, par: round.hole(n)?.par ?? hole?.par, strokes: round.totalStrokes, toPar: round.toPar,
                     distanceToPin: d, unit: unit == .meter ? "m" : "y")
    }
}

private func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
