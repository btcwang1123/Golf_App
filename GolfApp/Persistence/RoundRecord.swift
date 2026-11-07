import Foundation
import GolfKit
import SwiftData

@Model
final class RoundRecord {
    @Attribute(.unique) var id: UUID
    var courseId: String
    var courseName: String
    var startedAt: Date
    var endedAt: Date?
    var eventsData: Data
    var totalStrokes: Int?
    var toPar: Int?

    init(id: UUID, courseId: String, courseName: String, startedAt: Date, endedAt: Date? = nil,
         eventsData: Data = Data(), totalStrokes: Int? = nil, toPar: Int? = nil) {
        self.id = id
        self.courseId = courseId
        self.courseName = courseName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.eventsData = eventsData
        self.totalStrokes = totalStrokes
        self.toPar = toPar
    }

    var events: [RoundEvent] {
        get { (try? JSONDecoder().decode([RoundEvent].self, from: eventsData)) ?? [] }
        set { eventsData = (try? JSONEncoder().encode(newValue)) ?? eventsData }
    }
}
