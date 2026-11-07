import CoreLocation
import GolfKit
import Observation

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate, LocationProviding {
    private(set) var current: GeoPoint?
    private(set) var accuracy: Double?
    private(set) var authorizationStatus: CLAuthorizationStatus
    /// Incremented for every fix, so samplers can tell new fixes from repeats.
    private(set) var fixSerial = 0
    static let defaultDistanceFilter = 5.0

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var wantsUpdates = false

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool { authorizationStatus == .denied || authorizationStatus == .restricted }
    var isUndetermined: Bool { authorizationStatus == .notDetermined }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = Self.defaultDistanceFilter
    }

    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func start() {
        wantsUpdates = true
        if isAuthorized { manager.startUpdatingLocation() }
    }

    func stop() {
        wantsUpdates = false
        manager.stopUpdatingLocation()
    }

    /// Every fix (no distance filter) while surveying; otherwise 5 m.
    func setPrecise(_ precise: Bool) {
        manager.distanceFilter = precise ? kCLDistanceFilterNone : Self.defaultDistanceFilter
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let point = GeoPoint(last.coordinate)
        let acc = last.horizontalAccuracy >= 0 ? last.horizontalAccuracy : nil
        Task { @MainActor in
            self.current = point
            self.accuracy = acc
            self.fixSerial += 1
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if self.wantsUpdates, self.isAuthorized {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
