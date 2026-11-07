import Foundation
import GolfKit
import Observation
import OSLog
import SwiftData

@MainActor @Observable
final class RoundStore {
    private(set) var active: RoundState?
    private(set) var activeCourse: Course?
    private(set) var events: [RoundEvent] = []

    @ObservationIgnored var onEventsAppended: (([RoundEvent]) -> Void)?
    /// Called after the active round state changes (nil when it ends).
    @ObservationIgnored var onActiveChange: ((RoundState?, Course?) -> Void)?
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let courses: CourseRepository
    @ObservationIgnored private var activeRecord: RoundRecord?
    @ObservationIgnored private let log = Logger(subsystem: "GolfApp", category: "RoundStore")

    init(context: ModelContext, courses: CourseRepository) {
        self.context = context
        self.courses = courses
        restore()
    }

    // MARK: Public API

    func start(course: Course, roundId: UUID = UUID(), friends: [Player] = [], game: GameFormat = .stroke,
               bets: BetConfig? = nil) {
        endActiveIfNeeded()
        var t = Date()
        var events: [RoundEvent] = []
        func add(_ kind: RoundEvent.Kind) {
            events.append(RoundEvent(roundId: roundId, timestamp: t, source: .phone, kind: kind))
            t = t.addingTimeInterval(0.001)
        }
        add(.start(courseId: course.id))
        for p in friends.prefix(Player.maxPerRound - 1) { add(.addPlayer(p)) }
        if game != .stroke { add(.setGame(game)) }
        if let bets, !bets.isEmpty, !friends.isEmpty { add(.setBets(bets)) }
        let record = makeRecord(roundId: roundId, courseId: course.id, courseName: course.name, events: events)
        activate(record)
        onEventsAppended?(events)
    }

    /// Appends several events at once (e.g. all friends' scores for a hole).
    func append(_ kinds: [RoundEvent.Kind]) {
        guard let record = activeRecord, let roundId = active?.roundId, !kinds.isEmpty else { return }
        let now = Date()
        let new = kinds.enumerated().map { i, k in
            RoundEvent(roundId: roundId, timestamp: now.addingTimeInterval(Double(i) * 0.001), source: .phone, kind: k)
        }
        events = RoundReducer.merge(events, new)
        persist(record, events: events)
        recompute()
        onEventsAppended?(new)
    }

    /// Saves an imported round (from a `.golfround` file). Returns nil when it already exists.
    @discardableResult
    func importRound(events: [RoundEvent], courseId: String, courseName: String) -> RoundRecord? {
        guard let roundId = events.first?.roundId, record(id: roundId) == nil else { return nil }
        return makeRecord(roundId: roundId, courseId: courseId, courseName: courseName, events: events)
    }

    /// Events of a stored round, for exporting.
    func events(of record: RoundRecord) -> [RoundEvent] {
        record.id == active?.roundId ? events : record.events
    }

    /// Starts tracking a round begun elsewhere; emits nothing. No-op if already active.
    func adopt(roundId: UUID, courseId: String) {
        if active?.roundId == roundId { return }
        if let existing = record(id: roundId) {
            if existing.endedAt == nil {
                endActiveIfNeeded()
                activate(existing)
            }
            return
        }
        endActiveIfNeeded()
        let event = RoundEvent.make(roundId: roundId, source: .watch, kind: .start(courseId: courseId))
        let name = courses.course(id: courseId)?.name ?? courseId
        activate(makeRecord(roundId: roundId, courseId: courseId, courseName: name, events: [event]))
    }

    func append(_ kind: RoundEvent.Kind) {
        guard let record = activeRecord, let roundId = active?.roundId else { return }
        let event = RoundEvent.make(roundId: roundId, source: .phone, kind: kind)
        events = RoundReducer.merge(events, [event])
        persist(record, events: events)
        recompute()
        onEventsAppended?([event])
        if case .end = kind { deactivate() }
    }

    func end() {
        guard active != nil else { return }
        append(.end)
    }

    func merge(_ incoming: [RoundEvent]) {
        guard !incoming.isEmpty else { return }
        let grouped = Dictionary(grouping: incoming, by: \.roundId)
        for (roundId, evs) in grouped {
            if roundId == active?.roundId, let record = activeRecord {
                events = RoundReducer.merge(events, evs)
                persist(record, events: events)
                recompute()
                if active?.isEnded == true { deactivate() }
            } else if let record = record(id: roundId) {
                persist(record, events: RoundReducer.merge(record.events, evs))
            } else if let startEvent = evs.first(where: { if case .start = $0.kind { return true } else { return false } }),
                      case .start(let courseId) = startEvent.kind {
                let merged = RoundReducer.merge([], evs)
                let name = courses.course(id: courseId)?.name ?? courseId
                let record = makeRecord(roundId: roundId, courseId: courseId, courseName: name, events: merged)
                if record.endedAt == nil {
                    endActiveIfNeeded(excluding: roundId)
                    activate(record)
                }
            }
        }
    }

    func history() -> [RoundRecord] {
        let descriptor = FetchDescriptor<RoundRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func record(id: UUID) -> RoundRecord? {
        (try? context.fetch(FetchDescriptor<RoundRecord>(predicate: #Predicate { $0.id == id })))?.first
    }

    func delete(_ record: RoundRecord) {
        if record.id == active?.roundId { deactivate() }
        context.delete(record)
        save()
    }

    // MARK: Manual entry

    /// Saves a completed round typed in by hand (no GPS / watch). Does not touch the active round.
    @discardableResult
    func recordManual(courseId: String, courseName: String, date: Date, holes: [ManualHoleScore]) -> RoundRecord {
        let roundId = UUID()
        let events = ManualHoleScore.events(roundId: roundId, courseId: courseId, date: date, holes: holes)
        return makeRecord(roundId: roundId, courseId: courseId, courseName: courseName, events: events)
    }

    /// Replaces the scores of an existing manual round, keeping its id.
    func updateManual(_ record: RoundRecord, courseId: String, courseName: String, date: Date, holes: [ManualHoleScore]) {
        record.courseId = courseId
        record.courseName = courseName
        let events = ManualHoleScore.events(roundId: record.id, courseId: courseId, date: date, holes: holes)
        persist(record, events: events)
    }

    /// Call after the bundled course list finishes loading so par/green data applies.
    func courseDidLoad() {
        guard activeRecord != nil else { return }
        recompute()
    }

    static func state(of record: RoundRecord, course: Course?) -> RoundState {
        RoundReducer.reduce(record.events, course: course)
    }

    // MARK: Private

    private func restore() {
        let descriptor = FetchDescriptor<RoundRecord>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        let open = (try? context.fetch(descriptor)) ?? []
        guard let newest = open.first else { return }
        for stale in open.dropFirst() {
            let end = RoundEvent.make(roundId: stale.id, source: .phone, kind: .end)
            persist(stale, events: RoundReducer.merge(stale.events, [end]))
        }
        activate(newest)
    }

    private func makeRecord(roundId: UUID, courseId: String, courseName: String, events: [RoundEvent]) -> RoundRecord {
        let record = RoundRecord(id: roundId, courseId: courseId, courseName: courseName,
                                 startedAt: events.first?.timestamp ?? Date())
        context.insert(record)
        persist(record, events: events)
        return record
    }

    private func activate(_ record: RoundRecord) {
        activeRecord = record
        events = record.events
        recompute()
    }

    private func deactivate() {
        activeRecord = nil
        active = nil
        activeCourse = nil
        events = []
        onActiveChange?(nil, nil)
    }

    private func endActiveIfNeeded(excluding: UUID? = nil) {
        guard let record = activeRecord, let roundId = active?.roundId, roundId != excluding else { return }
        let end = RoundEvent.make(roundId: roundId, source: .phone, kind: .end)
        persist(record, events: RoundReducer.merge(events, [end]))
        onEventsAppended?([end])
        deactivate()
    }

    private func recompute() {
        guard let record = activeRecord else { return }
        let course = courses.course(id: record.courseId)
        activeCourse = course
        active = RoundReducer.reduce(events, course: course)
        onActiveChange?(active, course)
    }

    private func persist(_ record: RoundRecord, events: [RoundEvent]) {
        let course = courses.course(id: record.courseId)
        let state = RoundReducer.reduce(events, course: course)
        record.events = events
        record.endedAt = state.endedAt
        if let started = state.startedAt { record.startedAt = started }
        record.totalStrokes = state.totalStrokes
        record.toPar = state.toPar
        save()
    }

    private func save() {
        do { try context.save() } catch { log.error("save failed: \(error.localizedDescription)") }
    }
}
