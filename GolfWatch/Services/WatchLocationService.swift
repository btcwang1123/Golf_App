import CoreLocation
import Foundation
import GolfKit

@MainActor @Observable
final class WatchLocationService: NSObject, CLLocationManagerDelegate {
    struct Fix: Sendable, Equatable {
        var point: GeoPoint
        var date: Date
        var accuracy: Double
    }

    private(set) var current: GeoPoint?
    private(set) var lastFix: Fix?
    private(set) var isDenied = false
    private(set) var isUpdating = false
    /// Called on the main actor for every accepted fix.
    @ObservationIgnored var onUpdate: (@MainActor (GeoPoint) -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = kCLDistanceFilterNone
        isDenied = Self.denied(manager.authorizationStatus)
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func stop() {
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    /// Wrist down / always-on dimmed: 5 m distance filter to save power; full rate when awake.
    static let lowPowerDistanceFilter = 5.0

    func setLowPower(_ low: Bool) {
        manager.distanceFilter = low ? Self.lowPowerDistanceFilter : kCLDistanceFilterNone
        manager.desiredAccuracy = low ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyBest
    }

    /// Latest fix if it is fresh and accurate enough, else nil.
    func recentFix(maxAge: TimeInterval = 5, maxAccuracy: Double = 20, now: Date = Date()) -> GeoPoint? {
        guard let f = lastFix, f.accuracy >= 0, f.accuracy <= maxAccuracy,
              now.timeIntervalSince(f.date) <= maxAge else { return nil }
        return f.point
    }

    private static func denied(_ s: CLAuthorizationStatus) -> Bool {
        s == .denied || s == .restricted
    }

    private func receive(_ fixes: [Fix]) {
        guard let f = fixes.last else { return }
        lastFix = f
        current = f.point
        onUpdate?(f.point)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fixes = locations.map {
            Fix(point: GeoPoint(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude),
                date: $0.timestamp, accuracy: $0.horizontalAccuracy)
        }
        Task { @MainActor in self.receive(fixes) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.isDenied = Self.denied(status)
            if self.isUpdating, status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
