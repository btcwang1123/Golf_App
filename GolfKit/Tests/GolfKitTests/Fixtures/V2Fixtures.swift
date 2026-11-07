import Foundation
@testable import GolfKit

/// Shared helpers for V2 tests: a local metric frame and a simple mapped hole.
enum V2 {
    static let origin = GeoPoint(lat: 25.0, lon: 121.0)
    static let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    static func at(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: origin) }

    static func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> Polygon {
        [at(x0, y0), at(x1, y0), at(x1, y1), at(x0, y1)]
    }

    static func ev(_ rid: UUID, _ sec: Double, _ kind: RoundEvent.Kind, id: UUID = UUID()) -> RoundEvent {
        RoundEvent(id: id, roundId: rid, timestamp: t0.addingTimeInterval(sec), source: .phone, kind: kind)
    }

    /// Par-4 straight north, 380 m, green 30×30 at y 365…395.
    static func fullHole(_ n: Int = 1, par: Int = 4) -> Hole {
        let green = rect(-15, 365, 15, 395)
        return Hole(number: n, par: par, handicap: n, tee: origin, greenCenter: at(0, 380), green: green,
                    path: [origin, at(0, 380)],
                    features: [Feature(kind: .fairway, polygon: rect(-20, 150, 20, 340)),
                               Feature(kind: .bunker, polygon: rect(10, 220, 30, 240)),
                               Feature(kind: .green, polygon: green)])
    }

    static func course(holes: Int = 18) -> Course {
        Course(id: "c", name: "Test", center: origin, holes: (1...holes).map { fullHole($0) })
    }
}
