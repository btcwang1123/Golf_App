import Foundation

/// User preferences shared between iPhone and Watch.
public struct AppSettings: Sendable, Codable, Equatable, Hashable {
    public enum DistanceUnit: String, Sendable, Codable, CaseIterable {
        case yard, meter
    }

    public enum Wrist: String, Sendable, Codable, CaseIterable {
        case left, right
    }

    public static let metersPerYard = 0.9144
    public static let sensitivityRange: ClosedRange<Double> = 0.5...1.5
    public static let undoWindowRange: ClosedRange<Int> = 3...10

    public var distanceUnit: DistanceUnit
    public var wrist: Wrist
    public var swingSensitivity: Double
    public var undoWindowSeconds: Int
    public var autoAdvanceHole: Bool
    public var hapticsOn: Bool
    // V2
    public var onboardingCompleted: Bool
    public var celebrations: Bool
    public var autoFlyover: Bool
    public var distanceArcs: Bool
    public var windAdjustsClubs: Bool
    public var favoriteCourseId: String?
    /// Link encoded in the share-card QR code (App Store URL once released).
    public var shareURL: String

    public static let defaultShareURL = "https://apps.apple.com/app/golfapp"

    public init(
        distanceUnit: DistanceUnit = .yard,
        wrist: Wrist = .left,
        swingSensitivity: Double = 1.0,
        undoWindowSeconds: Int = 5,
        autoAdvanceHole: Bool = true,
        hapticsOn: Bool = true,
        onboardingCompleted: Bool = false,
        celebrations: Bool = true,
        autoFlyover: Bool = true,
        distanceArcs: Bool = true,
        windAdjustsClubs: Bool = true,
        favoriteCourseId: String? = nil,
        shareURL: String = AppSettings.defaultShareURL
    ) {
        self.distanceUnit = distanceUnit
        self.wrist = wrist
        self.swingSensitivity = swingSensitivity
        self.undoWindowSeconds = undoWindowSeconds
        self.autoAdvanceHole = autoAdvanceHole
        self.hapticsOn = hapticsOn
        self.onboardingCompleted = onboardingCompleted
        self.celebrations = celebrations
        self.autoFlyover = autoFlyover
        self.distanceArcs = distanceArcs
        self.windAdjustsClubs = windAdjustsClubs
        self.favoriteCourseId = favoriteCourseId
        self.shareURL = shareURL
    }

    private enum CodingKeys: String, CodingKey {
        case distanceUnit, wrist, swingSensitivity, undoWindowSeconds, autoAdvanceHole, hapticsOn
        case onboardingCompleted, celebrations, autoFlyover, distanceArcs, windAdjustsClubs, favoriteCourseId, shareURL
    }

    /// Missing keys (older versions) fall back to defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        distanceUnit = (try? c.decode(DistanceUnit.self, forKey: .distanceUnit)) ?? d.distanceUnit
        wrist = (try? c.decode(Wrist.self, forKey: .wrist)) ?? d.wrist
        swingSensitivity = (try? c.decode(Double.self, forKey: .swingSensitivity)) ?? d.swingSensitivity
        undoWindowSeconds = (try? c.decode(Int.self, forKey: .undoWindowSeconds)) ?? d.undoWindowSeconds
        autoAdvanceHole = (try? c.decode(Bool.self, forKey: .autoAdvanceHole)) ?? d.autoAdvanceHole
        hapticsOn = (try? c.decode(Bool.self, forKey: .hapticsOn)) ?? d.hapticsOn
        onboardingCompleted = (try? c.decode(Bool.self, forKey: .onboardingCompleted)) ?? d.onboardingCompleted
        celebrations = (try? c.decode(Bool.self, forKey: .celebrations)) ?? d.celebrations
        autoFlyover = (try? c.decode(Bool.self, forKey: .autoFlyover)) ?? d.autoFlyover
        distanceArcs = (try? c.decode(Bool.self, forKey: .distanceArcs)) ?? d.distanceArcs
        windAdjustsClubs = (try? c.decode(Bool.self, forKey: .windAdjustsClubs)) ?? d.windAdjustsClubs
        favoriteCourseId = try? c.decodeIfPresent(String.self, forKey: .favoriteCourseId)
        shareURL = (try? c.decode(String.self, forKey: .shareURL)) ?? d.shareURL
    }

    /// Distances for the 100/150/200 arcs in meters, in the display unit's round numbers.
    public var arcDistancesMeters: [Double] {
        let steps: [Double] = [100, 150, 200]
        return distanceUnit == .yard ? steps.map { $0 * Self.metersPerYard } : steps
    }

    public static let `default` = AppSettings()

    /// Converts meters into the configured display unit.
    public func displayValue(meters: Double) -> Double {
        switch distanceUnit {
        case .yard: meters / Self.metersPerYard
        case .meter: meters
        }
    }

    /// Rounded distance string, e.g. "152y" / "139m".
    public func format(meters: Double?) -> String {
        guard let meters else { return "--" }
        let v = Int(displayValue(meters: meters).rounded())
        return distanceUnit == .yard ? "\(v)y" : "\(v)m"
    }

    public var unitSuffix: String { distanceUnit == .yard ? "碼" : "公尺" }
}
