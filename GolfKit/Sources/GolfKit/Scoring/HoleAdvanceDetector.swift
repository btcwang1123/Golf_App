import Foundation

/// Suggests advancing to the next hole once the player has putted out and walked to the next tee.
public struct HoleAdvanceDetector: Sendable {
    public struct Config: Sendable, Codable, Equatable {
        /// Max distance (m) to the next tee to trigger.
        public var nextTeeRadius: Double
        /// Min distance (m) from the current green center.
        public var leaveGreenDistance: Double

        public init(nextTeeRadius: Double = 40, leaveGreenDistance: Double = 30) {
            self.nextTeeRadius = nextTeeRadius
            self.leaveGreenDistance = leaveGreenDistance
        }
    }

    public var config: Config

    public init(config: Config = Config()) {
        self.config = config
    }

    /// Returns `current + 1` when a hole advance is suggested, else nil.
    /// The `autoAdvanceHole` setting is checked by the caller.
    public func suggest(current: Int, location: GeoPoint, state: HoleState, course: Course) -> Int? {
        guard course.hasHoleMaps, state.putts > 0 else { return nil }
        let next = current + 1
        guard let nextTee = course.holes.first(where: { $0.number == next })?.effectiveTee else { return nil }
        guard Geo.distance(location, nextTee) < config.nextTeeRadius else { return nil }
        if let green = course.holes.first(where: { $0.number == current })?.effectiveGreenCenter,
           Geo.distance(location, green) <= config.leaveGreenDistance {
            return nil
        }
        return next
    }

    public static func suggest(current: Int, location: GeoPoint, state: HoleState, course: Course) -> Int? {
        HoleAdvanceDetector().suggest(current: current, location: location, state: state, course: course)
    }
}
