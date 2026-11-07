import Foundation
import GolfKit
import Observation
import SwiftData

struct CourseListItem: Identifiable, Hashable {
    var course: Course
    var distanceMeters: Double?
    var quality: CourseQuality.Level = .scoreOnly
    var id: String { course.id }
    var isFeatured: Bool { course.source == .featured }
}

/// Bundled OSM courses, bundled featured courses and the user's own courses.
/// Merge priority: user > featured > osm; featured courses hide the OSM course they `replaces`.
@MainActor @Observable
final class CourseRepository {
    /// Courses whose distance differs by less than this are "the same distance" (featured first).
    static let sameDistanceBucketMeters = 1_000.0
    nonisolated static let featuredDirectory = "featured"

    private(set) var isLoaded = false
    private var builtin: [Course] = []
    private var featured: [Course] = []
    private var userCourses: [String: Course] = [:]
    private var merged: [Course] = []
    private var index: [String: Course] = [:]
    private var qualities: [String: CourseQuality] = [:]
    /// OSM id → featured id, so old rounds on a replaced course still resolve.
    private var aliases: [String: String] = [:]

    @ObservationIgnored private let context: ModelContext?

    init(context: ModelContext?) {
        self.context = context
        loadUserCourses()
        rebuild()
    }

    /// In-memory repository with a fixed course list (showcase / previews).
    init(courses: [Course]) {
        self.context = nil
        builtin = courses
        isLoaded = true
        rebuild()
    }

    func load() async {
        let (osm, feat) = await Task.detached(priority: .userInitiated) { () -> ([Course], [Course]) in
            let started = Date()
            let osm: [Course] = {
                guard let url = Bundle.main.url(forResource: "courses_tw", withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let list = try? Course.decodeList(from: data) else { return [] }
                // Fairways / bunkers / water auto-traced from open aerial imagery (Tools/autotrace).
                var withAerial = list
                if let aURL = Bundle.main.url(forResource: "aerial_tw", withExtension: "json"),
                   let aData = try? Data(contentsOf: aURL),
                   let aerial = try? JSONDecoder().decode(AerialFeatureSet.self, from: aData) {
                    withAerial = aerial.apply(to: list)
                }
                // Courses with mapped greens but no OSM holes: one hole per green, pin at its center.
                return HoleSynthesizer.apply(to: withAerial)
            }()
            let feat = Self.loadFeatured(bundle: .main)
            DiagnosticsService.recordTiming("courses.load", seconds: Date().timeIntervalSince(started))
            return (osm, feat)
        }.value
        builtin = osm
        featured = feat
        rebuild()
        isLoaded = true
    }

    nonisolated static func loadFeatured(bundle: Bundle) -> [Course] {
        guard let dir = bundle.url(forResource: featuredDirectory, withExtension: nil),
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return urls.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      var c = try? JSONDecoder().decode(Course.self, from: data) else { return nil }
                c.source = .featured
                return c
            }
    }

    func all() -> [Course] { merged }

    func course(id: String) -> Course? { index[id] ?? aliases[id].flatMap { index[$0] } }

    func quality(id: String) -> CourseQuality {
        if let q = qualities[id] { return q }
        return course(id: id).map(CourseQuality.evaluate) ?? CourseQuality(level: .scoreOnly, holes: [], score: 0)
    }

    var featuredCourses: [Course] { merged.filter { $0.source == .featured } }

    func search(_ q: String) -> [Course] {
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return merged }
        return merged.filter { $0.name.localizedStandardContains(query) || ($0.county?.localizedStandardContains(query) ?? false) }
    }

    func nearby(_ p: GeoPoint, limit: Int) -> [Course] {
        Array(merged.sorted { Geo.distance(p, $0.center) < Geo.distance(p, $1.center) }.prefix(max(0, limit)))
    }

    /// Search + sort for list display: by distance (featured first within the same bucket) when `near` is known,
    /// else featured first then by name.
    func list(query: String, near: GeoPoint?) -> [CourseListItem] {
        search(query)
            .map { c in
                CourseListItem(course: c, distanceMeters: near.map { Geo.distance($0, c.center) },
                               quality: qualities[c.id]?.level ?? .scoreOnly)
            }
            .sorted { a, b in
                if let da = a.distanceMeters, let db = b.distanceMeters {
                    let ba = Int(da / Self.sameDistanceBucketMeters), bb = Int(db / Self.sameDistanceBucketMeters)
                    if ba != bb { return ba < bb }
                    if a.isFeatured != b.isFeatured { return a.isFeatured }
                    return da < db
                }
                if a.isFeatured != b.isFeatured { return a.isFeatured }
                return a.course.name.localizedStandardCompare(b.course.name) == .orderedAscending
            }
    }

    func isUserCourse(id: String) -> Bool { userCourses[id] != nil }

    func save(userCourse: Course) {
        var course = userCourse
        if course.source != .user { course.source = .user }
        userCourses[course.id] = course
        if let context, let data = try? JSONEncoder().encode(course) {
            let id = course.id
            let existing = (try? context.fetch(FetchDescriptor<UserCourseRecord>(predicate: #Predicate { $0.id == id })))?.first
            if let existing {
                existing.courseJSON = data
                existing.updatedAt = Date()
            } else {
                context.insert(UserCourseRecord(id: id, courseJSON: data))
            }
            try? context.save()
        }
        rebuild()
    }

    func deleteUserCourse(id: String) {
        if let context {
            let records = (try? context.fetch(FetchDescriptor<UserCourseRecord>(predicate: #Predicate { $0.id == id }))) ?? []
            records.forEach { context.delete($0) }
            try? context.save()
        }
        userCourses[id] = nil
        rebuild()
    }

    private func loadUserCourses() {
        guard let context else { return }
        let records = (try? context.fetch(FetchDescriptor<UserCourseRecord>())) ?? []
        var dict: [String: Course] = [:]
        for r in records {
            if let c = try? JSONDecoder().decode(Course.self, from: r.courseJSON) { dict[r.id] = c }
        }
        userCourses = dict
    }

    private func rebuild() {
        var dict: [String: Course] = [:]
        var order: [String] = []
        var alias: [String: String] = [:]
        let replaced = Set(featured.compactMap(\.replaces))
        for c in featured { if let r = c.replaces { alias[r] = c.id } }
        for c in builtin where dict[c.id] == nil && !replaced.contains(c.id) { dict[c.id] = c; order.append(c.id) }
        for c in featured {
            if dict[c.id] == nil { order.append(c.id) }
            dict[c.id] = c
        }
        for (id, c) in userCourses.sorted(by: { $0.key < $1.key }) {
            if dict[id] == nil { order.append(id) }
            dict[id] = c
        }
        index = dict
        aliases = alias
        merged = order.compactMap { dict[$0] }
        var q: [String: CourseQuality] = [:]
        for c in merged { q[c.id] = CourseQuality.evaluate(c) }
        qualities = q
    }
}
