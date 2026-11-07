import Foundation

/// Map-data completeness of one hole.
public struct HoleQuality: Sendable, Codable, Equatable, Hashable {
    public enum Item: String, Sendable, Codable, Equatable, Hashable, CaseIterable, Comparable {
        case tee, greenCenter, greenPolygon, par, fairway, hazards, handicap

        /// Items required for a hole to count as fully mapped.
        public var isRequired: Bool { CourseQuality.requiredItems.contains(self) }

        public static func < (a: Item, b: Item) -> Bool {
            allCases.firstIndex(of: a) ?? 0 < allCases.firstIndex(of: b) ?? 0
        }
    }

    public var number: Int
    public var missing: Set<Item>

    public init(number: Int, missing: Set<Item>) {
        self.number = number
        self.missing = missing
    }

    public static func evaluate(_ hole: Hole, courseFeatures: [Feature] = []) -> HoleQuality {
        var missing = Set<Item>()
        if hole.effectiveTee == nil { missing.insert(.tee) }
        if hole.greenCenter == nil && hole.green == nil { missing.insert(.greenCenter) }
        if (hole.green?.count ?? 0) < 3 { missing.insert(.greenPolygon) }
        if hole.par == nil { missing.insert(.par) }
        let kinds = Set(hole.features.map(\.kind))
        if !kinds.contains(.fairway) { missing.insert(.fairway) }
        if kinds.isDisjoint(with: CourseQuality.hazardKinds) { missing.insert(.hazards) }
        if hole.handicap == nil { missing.insert(.handicap) }
        return HoleQuality(number: hole.number, missing: missing)
    }

    /// Required items present (tee, green center, green polygon, par).
    public var isComplete: Bool { missing.isDisjoint(with: CourseQuality.requiredItems) }
    /// Enough to measure distances: tee + green center.
    public var isPlayable: Bool { !missing.contains(.tee) && !missing.contains(.greenCenter) }

    public var level: CourseQuality.Level {
        isComplete ? .full : isPlayable ? .partial : .scoreOnly
    }

    /// 0...1: required items weigh `requiredWeight`, optional ones share the rest.
    public var score: Double {
        let req = CourseQuality.requiredItems
        let opt = Set(Item.allCases).subtracting(req)
        let reqHave = Double(req.subtracting(missing).count) / Double(req.count)
        let optHave = Double(opt.subtracting(missing).count) / Double(max(opt.count, 1))
        return reqHave * CourseQuality.requiredWeight + optHave * (1 - CourseQuality.requiredWeight)
    }
}
