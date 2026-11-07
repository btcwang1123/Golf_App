import Foundation
import SwiftData

extension ModelContainer {
    static func app() -> ModelContainer {
        let schema = Schema([
            RoundRecord.self, UserCourseRecord.self, HolePlanRecord.self, RoundPhotoRecord.self, PracticeRecord.self,
        ])
        if let container = try? ModelContainer(for: schema) { return container }
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: memory)
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }
    }
}
