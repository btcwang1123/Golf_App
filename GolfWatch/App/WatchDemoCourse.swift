import Foundation
import GolfKit

/// Synthetic mapped hole used for UI-test screenshots on the watch.
enum WatchDemoCourse {
    static func make() -> Course {
        let o = GeoPoint(lat: 25.0, lon: 121.5)
        func at(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: o) }
        let green: Polygon = (0..<12).map { i in
            let a = Double(i) / 12 * 2 * .pi
            return at(10 + 14 * sin(a), 360 + 17 * cos(a))
        }
        let hole = Hole(
            number: 1, par: 4, handicap: 5, tee: o, greenCenter: at(10, 360), green: green,
            path: [o, at(5, 220), at(10, 360)],
            features: [
                Feature(kind: .fairway, polygon: [at(-22, 160), at(18, 150), at(32, 230), at(24, 330), at(-4, 335), at(-20, 250)]),
                Feature(kind: .green, polygon: green),
                Feature(kind: .bunker, polygon: [at(28, 340), at(42, 342), at(44, 356), at(30, 360)]),
                Feature(kind: .water, polygon: [at(-30, 185), at(-12, 182), at(-10, 240), at(-28, 250)]),
            ])
        return Course(id: "watch-demo", name: "Demo", center: o, holes: [hole], source: .featured, provenance: .survey)
    }
}
