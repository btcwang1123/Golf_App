import Foundation
import GolfKit
import SwiftData

/// The player's plan / note for one hole of a course (kept across rounds).
@Model
final class HolePlanRecord {
    @Attribute(.unique) var key: String
    var courseId: String
    var hole: Int
    var planData: Data

    init(plan: HolePlan) {
        key = plan.id
        courseId = plan.courseId
        hole = plan.hole
        planData = (try? JSONEncoder().encode(plan)) ?? Data()
    }

    var plan: HolePlan {
        get { (try? JSONDecoder().decode(HolePlan.self, from: planData)) ?? HolePlan(courseId: courseId, hole: hole) }
        set { planData = (try? JSONEncoder().encode(newValue)) ?? planData }
    }
}

/// A photo taken during a round on a given hole.
@Model
final class RoundPhotoRecord {
    @Attribute(.unique) var id: UUID
    var roundId: UUID
    var hole: Int
    var createdAt: Date
    @Attribute(.externalStorage) var imageData: Data

    init(id: UUID = UUID(), roundId: UUID, hole: Int, createdAt: Date = Date(), imageData: Data) {
        self.id = id
        self.roundId = roundId
        self.hole = hole
        self.createdAt = createdAt
        self.imageData = imageData
    }
}

/// A driving-range session received from the watch.
@Model
final class PracticeRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var swingCount: Int
    var sessionData: Data

    init(session: PracticeSession) {
        id = session.id
        startedAt = session.startedAt
        swingCount = session.swings.count
        sessionData = (try? JSONEncoder().encode(session)) ?? Data()
    }

    var session: PracticeSession? { try? JSONDecoder().decode(PracticeSession.self, from: sessionData) }
}
