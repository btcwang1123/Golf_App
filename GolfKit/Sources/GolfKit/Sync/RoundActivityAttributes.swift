import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// Live Activity payload for a round in progress.
public struct RoundActivityAttributes: Sendable, Codable, Hashable {
    public struct ContentState: Sendable, Codable, Hashable {
        public var hole: Int
        public var par: Int?
        public var strokes: Int
        public var toPar: Int?
        public var distanceToPin: Double?
        /// "y" or "m"
        public var unit: String

        public init(hole: Int, par: Int?, strokes: Int, toPar: Int?, distanceToPin: Double?, unit: String = "y") {
            self.hole = hole
            self.par = par
            self.strokes = strokes
            self.toPar = toPar
            self.distanceToPin = distanceToPin
            self.unit = unit
        }

        public var distanceText: String {
            guard let d = distanceToPin else { return "--" }
            let v = unit == "m" ? d : d / AppSettings.metersPerYard
            return "\(Int(v.rounded()))\(unit)"
        }

        public var toParText: String {
            guard let t = toPar else { return "E" }
            return t == 0 ? "E" : t > 0 ? "+\(t)" : "−\(-t)"
        }
    }

    public var courseName: String

    public init(courseName: String) {
        self.courseName = courseName
    }
}

#if canImport(ActivityKit) && os(iOS)
extension RoundActivityAttributes: ActivityAttributes {}
#endif

/// Throttling rule for Live Activity distance updates.
public struct ActivityUpdateThrottle: Sendable {
    public static let minMoveMeters = 5.0
    public static let maxPerMinute = 4

    private var lastLocation: GeoPoint?
    private var recent: [Date] = []

    public init() {}

    /// True when a location-driven update should be sent now (and records it).
    public mutating func shouldUpdate(location: GeoPoint, now: Date = Date()) -> Bool {
        if let last = lastLocation, Geo.distance(last, location) < Self.minMoveMeters { return false }
        recent = recent.filter { now.timeIntervalSince($0) < 60 }
        guard recent.count < Self.maxPerMinute else { return false }
        recent.append(now)
        lastLocation = location
        return true
    }

    /// Record an event-driven update (stroke / hole change), which is always sent.
    public mutating func recordForced(location: GeoPoint?, now: Date = Date()) {
        recent = recent.filter { now.timeIntervalSince($0) < 60 }
        recent.append(now)
        if let location { lastLocation = location }
    }
}
