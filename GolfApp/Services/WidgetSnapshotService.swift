import Foundation
import GolfKit
import WidgetKit

/// Writes the home-screen widget's data into the shared app group.
@MainActor
enum WidgetSnapshotService {
    static func update(records: [RoundRecord], courses: CourseRepository, teeTimes: [TeeTime]) {
        let finished = records.filter { $0.endedAt != nil && ($0.totalStrokes ?? 0) > 0 }
            .sorted { $0.startedAt > $1.startedAt }
        let recent = finished.prefix(10).map { RoundStore.state(of: $0, course: courses.course(id: $0.courseId)) }
        var last: HomeWidgetSnapshot.LastRound?
        if let r = finished.first, let s = recent.first {
            last = .init(courseName: r.courseName, date: r.startedAt, strokes: s.totalStrokes, toPar: s.toPar, holes: s.holesPlayed)
        }
        let trend = recent.reversed().compactMap { s -> Double? in
            guard let tp = s.toPar, s.holesPlayed > 0 else { return nil }
            return Double(tp) * 18 / Double(s.holesPlayed)
        }
        let year = Calendar.current.component(.year, from: Date())
        let thisYear = finished.filter { Calendar.current.component(.year, from: $0.startedAt) == year }.count
        let all = finished.prefix(200).map { RoundStore.state(of: $0, course: courses.course(id: $0.courseId)) }
        let unlocks = AchievementEngine.unlocks(rounds: Array(all)).count
        let next = TeeTime.upcoming(teeTimes).first { $0.date > Date() }
        let snap = HomeWidgetSnapshot(
            lastRound: last,
            averageToPar: trend.isEmpty ? nil : trend.reduce(0, +) / Double(trend.count),
            trend: Array(trend.suffix(10)), roundsThisYear: thisYear, achievements: unlocks,
            nextTeeTime: next.map { .init(courseName: $0.courseName, date: $0.date) })
        let defaults = UserDefaults(suiteName: HomeWidgetSnapshot.appGroup)
        guard HomeWidgetSnapshot.load(from: defaults).map({ !same($0, snap) }) ?? true else { return }
        snap.save(to: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomeStatsWidget")
    }

    private static func same(_ a: HomeWidgetSnapshot, _ b: HomeWidgetSnapshot) -> Bool {
        var x = a, y = b
        x.updatedAt = .distantPast
        y.updatedAt = .distantPast
        return x == y
    }
}
