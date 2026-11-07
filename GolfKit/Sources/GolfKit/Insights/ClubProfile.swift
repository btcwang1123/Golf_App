import Foundation

/// Per-club carry statistics built from tagged shots.
public struct ClubProfile: Sendable, Codable, Equatable, Hashable {
    public struct Stats: Sendable, Codable, Equatable, Hashable {
        public var count: Int
        public var median: Double
        public var p25: Double
        public var p75: Double
        public var longest: Double
        public var dispersion: [DispersionPoint]

        public init(count: Int, median: Double, p25: Double, p75: Double, longest: Double, dispersion: [DispersionPoint] = []) {
            self.count = count
            self.median = median
            self.p25 = p25
            self.p75 = p75
            self.longest = longest
            self.dispersion = dispersion
        }
    }

    public static let validRange: ClosedRange<Double> = 10...350
    /// Clubs with fewer samples are not used for advice.
    public static let minSamples = 3
    /// Default driving distance (m) when there is no driver data: 200 yd.
    public static let defaultDrive = 200 * AppSettings.metersPerYard

    public var clubs: [Club: Stats]

    public init(clubs: [Club: Stats] = [:]) {
        self.clubs = clubs
    }

    public subscript(_ club: Club) -> Stats? { clubs[club] }

    /// Clubs ordered longest to shortest by median.
    public var ordered: [(club: Club, stats: Stats)] {
        clubs.map { ($0.key, $0.value) }.sorted { $0.stats.median > $1.stats.median }
    }

    /// Typical tee shot distance: driver median when reliable, else 200 yd.
    public var driveDistance: Double {
        if let d = clubs[.driver], d.count >= Self.minSamples { return d.median }
        return Self.defaultDrive
    }

    public static func build(rounds: [RoundState], courses: [String: Course]) -> ClubProfile {
        var samples: [Club: [Double]] = [:]
        var disp: [Club: [DispersionPoint]] = [:]
        for r in rounds {
            let course = r.courseId.flatMap { courses[$0] }
            for h in r.holes {
                let penalized = Set(h.penalizedShotIds)
                let target = r.pins[h.number] ?? course?.hole(h.number)?.effectiveGreenCenter
                for (i, shot) in h.shots.enumerated() {
                    guard let club = shot.club, club != .putter, shot.type != .putt,
                          !penalized.contains(shot.id), let d = shot.distanceToNext,
                          validRange.contains(d) else { continue }
                    samples[club, default: []].append(d)
                    if let start = shot.location, let target,
                       let next = h.shots[(i + 1)...].first(where: { $0.location != nil })?.location {
                        disp[club, default: []].append(DispersionStats.relative(shot: start, next: next, target: target))
                    }
                }
            }
        }
        var out: [Club: Stats] = [:]
        for (club, values) in samples {
            let v = values.sorted()
            out[club] = Stats(
                count: v.count, median: percentile(v, 0.5), p25: percentile(v, 0.25), p75: percentile(v, 0.75),
                longest: v.last ?? 0, dispersion: disp[club] ?? [])
        }
        return ClubProfile(clubs: out)
    }

    /// Linear-interpolated percentile of sorted values.
    public static func percentile(_ sorted: [Double], _ q: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let pos = q * Double(sorted.count - 1)
        let lo = Int(pos.rounded(.down)), hi = Int(pos.rounded(.up))
        let f = pos - Double(lo)
        return sorted[lo] * (1 - f) + sorted[hi] * f
    }
}
