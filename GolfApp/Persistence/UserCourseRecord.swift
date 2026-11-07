import Foundation
import SwiftData

@Model
final class UserCourseRecord {
    @Attribute(.unique) var id: String
    var courseJSON: Data
    var updatedAt: Date

    init(id: String, courseJSON: Data, updatedAt: Date = Date()) {
        self.id = id
        self.courseJSON = courseJSON
        self.updatedAt = updatedAt
    }
}
