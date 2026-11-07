import GolfKit
import SwiftUI

/// A source of the player's position. The real one is `LocationService`; the showcase injects a simulated one.
@MainActor
protocol LocationProviding: AnyObject {
    var current: GeoPoint? { get }
    var accuracy: Double? { get }
    var isAuthorized: Bool { get }
    func requestPermission()
    func start()
    func stop()
}

extension EnvironmentValues {
    /// Overrides `LocationService` for views that read `resolvedLocation` (showcase mode).
    @Entry var locationOverride: (any LocationProviding)? = nil
    /// True inside the showcase: no Live Activities, no sync, no history writes.
    @Entry var isShowcase = false
}
