import Foundation

/// Tunable timings and limits for the watch round flow.
struct WatchRoundConfig: Sendable, Equatable {
    /// Used when the configured undo window is not positive.
    var fallbackToastSeconds: Int = 5
    /// How long the auto-advance "退回" banner stays visible.
    var advanceBannerSeconds: Int = 6
    /// Max recently synced courses listed on the start screen.
    var recentCoursesLimit: Int = 8
    /// Hole count used for navigation when the course has no hole list.
    var defaultHoleCount: Int = 18
    /// Location fix freshness / accuracy required to attach a position to a stroke.
    var fixMaxAge: TimeInterval = 5
    var fixMaxAccuracy: Double = 20
    /// Digital crown stroke-count range.
    var crownMax: Double = 30

    static let `default` = WatchRoundConfig()
}
