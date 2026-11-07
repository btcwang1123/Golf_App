import Foundation

/// Map-data completeness of a course. All rules live in the constants below.
public struct CourseQuality: Sendable, Codable, Equatable, Hashable {
    public enum Level: String, Sendable, Codable, Equatable, Hashable, CaseIterable, Comparable {
        case full, partial, scoreOnly

        public var label: String {
            switch self {
            case .full: "完整圖資"
            case .partial: "部分圖資"
            case .scoreOnly: "僅記桿"
            }
        }

        private var rank: Int {
            switch self {
            case .full: 0
            case .partial: 1
            case .scoreOnly: 2
            }
        }

        public static func < (a: Level, b: Level) -> Bool { a.rank < b.rank }
    }

    public static let requiredItems: Set<HoleQuality.Item> = [.tee, .greenCenter, .greenPolygon, .par]
    public static let hazardKinds: Set<Feature.Kind> = [.bunker, .water, .lateralWater]
    /// Share of holes that must have tee + green center for `.partial`.
    public static let partialHoleShare = 0.5
    /// Weight of required items in `score`.
    public static let requiredWeight = 0.8

    public var level: Level
    public var holes: [HoleQuality]
    public var score: Double

    public init(level: Level, holes: [HoleQuality], score: Double) {
        self.level = level
        self.holes = holes
        self.score = score
    }

    public static func evaluate(_ c: Course) -> CourseQuality {
        let holes = c.holes.sorted { $0.number < $1.number }.map { HoleQuality.evaluate($0, courseFeatures: c.features) }
        guard !holes.isEmpty else { return CourseQuality(level: .scoreOnly, holes: [], score: 0) }
        let level: Level
        if holes.allSatisfy(\.isComplete) {
            level = .full
        } else if Double(holes.filter(\.isPlayable).count) >= Double(holes.count) * partialHoleShare {
            level = .partial
        } else {
            level = .scoreOnly
        }
        let score = holes.reduce(0) { $0 + $1.score } / Double(holes.count)
        return CourseQuality(level: level, holes: holes, score: min(1, max(0, score)))
    }

    public func hole(_ number: Int) -> HoleQuality? { holes.first { $0.number == number } }

    /// Total missing items over all holes.
    public var missingCount: Int { holes.reduce(0) { $0 + $1.missing.count } }
    /// Missing required items over all holes.
    public var missingRequiredCount: Int {
        holes.reduce(0) { $0 + $1.missing.intersection(Self.requiredItems).count }
    }
}

extension Course {
    public var quality: CourseQuality { CourseQuality.evaluate(self) }
}
