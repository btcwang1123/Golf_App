import Foundation
import GolfKit

/// Individual course JSON files in Application Support/Courses/<id>.json
/// (the watch only keeps courses that were sent to it).
struct WatchCourseCache: Sendable {
    struct Summary: Sendable, Equatable, Identifiable {
        var id: String
        var name: String
        var county: String?
        var modified: Date
    }

    let directory: URL

    init(directory: URL = WatchCourseCache.defaultDirectory()) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func appSupport() -> URL {
        let fm = FileManager.default
        let url = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return url ?? fm.temporaryDirectory
    }

    static func defaultDirectory() -> URL {
        appSupport().appendingPathComponent("Courses", isDirectory: true)
    }

    private func fileURL(_ id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(safe).json")
    }

    func save(_ course: Course) {
        guard let data = try? JSONEncoder().encode(course) else { return }
        try? data.write(to: fileURL(course.id), options: .atomic)
    }

    func load(id: String) -> Course? {
        guard let data = try? Data(contentsOf: fileURL(id)) else { return nil }
        return try? JSONDecoder().decode(Course.self, from: data)
    }

    /// Most recently synced first.
    func summaries(limit: Int) -> [Summary] {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var out: [Summary] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let course = try? JSONDecoder().decode(Course.self, from: data) else { continue }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            out.append(Summary(id: course.id, name: course.name, county: course.county, modified: date))
        }
        return Array(out.sorted { $0.modified > $1.modified }.prefix(limit))
    }
}
