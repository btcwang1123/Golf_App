import Foundation

/// Course features auto-traced from open aerial imagery (Tools/autotrace), keyed by course id.
/// Bundled separately from `courses_tw.json` so re-running osm-import does not drop them.
public struct AerialFeatureSet: Sendable, Codable, Equatable {
    public var attribution: String
    public var courses: [String: [Feature]]

    public init(attribution: String, courses: [String: [Feature]]) {
        self.attribution = attribution
        self.courses = courses
    }

    /// Appends each course's aerial features to its course-level features.
    public func apply(to list: [Course]) -> [Course] {
        list.map { course in
            guard let extra = courses[course.id], !extra.isEmpty else { return course }
            var c = course
            c.features += extra.filter { !c.features.contains($0) }
            return c
        }
    }
}
