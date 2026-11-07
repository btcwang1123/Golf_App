import Foundation

public enum ClubAdvisor {
    public struct Suggestion: Sendable, Equatable, Hashable {
        public var club: Club
        /// Median distance of the club (m).
        public var expected: Double
        public var alternative: Club?
        /// Wind-adjusted plays-like distance (m).
        public var playsLike: Double

        public init(club: Club, expected: Double, alternative: Club?, playsLike: Double) {
            self.club = club
            self.expected = expected
            self.alternative = alternative
            self.playsLike = playsLike
        }
    }

    /// Plays-like change per m/s of headwind / tailwind.
    public static let headwindFactor = 0.01
    public static let tailwindFactor = 0.005
    /// A club qualifies when its median reaches this share of the target.
    public static let reachShare = 0.95

    public static func playsLike(distance: Double, headwind: Double?) -> Double {
        guard let w = headwind else { return distance }
        return distance * (1 + (w >= 0 ? w * headwindFactor : w * tailwindFactor))
    }

    public static func hasEnoughData(_ profile: ClubProfile) -> Bool {
        profile.clubs.contains { $0.key != .putter && $0.value.count >= ClubProfile.minSamples }
    }

    public static func suggest(distance: Double, profile: ClubProfile, headwind: Double?) -> Suggestion? {
        let target = playsLike(distance: distance, headwind: headwind)
        let eligible = profile.clubs
            .filter { $0.key != .putter && $0.value.count >= ClubProfile.minSamples }
            .map { (club: $0.key, median: $0.value.median) }
            .sorted { $0.median < $1.median }
        guard !eligible.isEmpty else { return nil }
        let reaching = eligible.filter { $0.median >= target * reachShare }
        let pick = reaching.min { abs($0.median - target) < abs($1.median - target) } ?? eligible[eligible.count - 1]
        let alt = eligible.filter { $0.club != pick.club }.min { abs($0.median - target) < abs($1.median - target) }
        return Suggestion(club: pick.club, expected: pick.median, alternative: alt?.club, playsLike: target)
    }
}
