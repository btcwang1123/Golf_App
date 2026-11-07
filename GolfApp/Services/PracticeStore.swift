import Foundation
import GolfKit
import Observation
import SwiftData

/// Driving-range sessions synced from the watch.
@MainActor @Observable
final class PracticeStore {
    private(set) var revision = 0
    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func sessions() -> [PracticeSession] {
        _ = revision
        let d = FetchDescriptor<PracticeRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return ((try? context.fetch(d)) ?? []).compactMap(\.session)
    }

    func save(_ session: PracticeSession) {
        let id = session.id
        let d = FetchDescriptor<PracticeRecord>(predicate: #Predicate { $0.id == id })
        if let existing = (try? context.fetch(d))?.first { context.delete(existing) }
        context.insert(PracticeRecord(session: session))
        try? context.save()
        revision += 1
    }

    func delete(id: UUID) {
        let d = FetchDescriptor<PracticeRecord>(predicate: #Predicate { $0.id == id })
        for r in (try? context.fetch(d)) ?? [] { context.delete(r) }
        try? context.save()
        revision += 1
    }
}
