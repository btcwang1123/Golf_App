import GolfKit
import Observation

/// Walks along a track at `speed` m/s, publishing positions like a GPS.
@MainActor @Observable
final class SimulatedLocationProvider: LocationProviding {
    private(set) var current: GeoPoint?
    private(set) var accuracy: Double? = 4
    let isAuthorized = true
    var speed: Double

    static let tick = 0.1

    init(track: [GeoPoint] = [], speed: Double = 1.4) {
        self.speed = speed
        current = track.first
    }

    func requestPermission() {}
    func start() {}
    func stop() {}

    func teleport(_ p: GeoPoint) { current = p }

    /// Moves along `track` at `speed`; returns when done or cancelled. `isPaused` is polled each tick.
    func walk(_ track: [GeoPoint], isPaused: @escaping @MainActor () -> Bool) async {
        guard var from = current ?? track.first else { return }
        for to in track {
            let d = Geo.distance(from, to)
            let steps = max(1, Int(d / max(speed * Self.tick, 0.01)))
            let b = Geo.bearing(from, to)
            for i in 1...steps {
                while isPaused() {
                    try? await Task.sleep(for: .seconds(Self.tick))
                    if Task.isCancelled { return }
                }
                if Task.isCancelled { return }
                current = Geo.destination(from: from, bearing: b, meters: d * Double(i) / Double(steps))
                try? await Task.sleep(for: .seconds(Self.tick))
            }
            from = to
        }
    }
}
