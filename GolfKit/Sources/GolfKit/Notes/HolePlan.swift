import Foundation

/// The player's own plan and notes for one hole of a course; shown every time they play it.
public struct HolePlan: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var courseId: String
    public var hole: Int
    /// Aim points in play order (tee shot first).
    public var targets: [GeoPoint]
    /// Planned club per target (same order; may be shorter).
    public var clubs: [Club]
    public var note: String
    public var updatedAt: Date

    public var id: String { Self.key(courseId: courseId, hole: hole) }

    public init(courseId: String, hole: Int, targets: [GeoPoint] = [], clubs: [Club] = [], note: String = "",
                updatedAt: Date = Date()) {
        self.courseId = courseId
        self.hole = hole
        self.targets = targets
        self.clubs = clubs
        self.note = note
        self.updatedAt = updatedAt
    }

    public static func key(courseId: String, hole: Int) -> String { "\(courseId)#\(hole)" }

    public var isEmpty: Bool { targets.isEmpty && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public func club(for index: Int) -> Club? { clubs.indices.contains(index) ? clubs[index] : nil }

    /// Meters between the planned tee-shot target and where the tee shot actually ended up.
    public func teeShotMiss(_ hole: HoleState) -> Double? {
        guard let target = targets.first, hole.shots.count >= 2, hole.shots[0].type != .putt,
              let landing = hole.shots[1].location else { return nil }
        return Geo.distance(target, landing)
    }

    /// Plan-vs-actual summary over a round: average tee-shot miss and how many holes had a plan.
    public static func adherence(plans: [Int: HolePlan], round: RoundState) -> (holes: Int, averageMiss: Double)? {
        let misses = round.holes.compactMap { h in plans[h.number]?.teeShotMiss(h) }
        guard !misses.isEmpty else { return nil }
        return (misses.count, misses.reduce(0, +) / Double(misses.count))
    }
}
