import Foundation
import GolfKit

/// Timeline for the showcase: flyover → walk → auto +1 → distances → putts → summary → share card.
struct ShowcaseScript: Decodable {
    struct HoleScript: Decodable {
        var number: Int
        /// Shot start positions as a fraction of the hole's centre line (0 = tee).
        var shots: [Double]
        /// Lateral offsets (m, + = right) of those positions.
        var lateral: [Double]
        var putts: Int
        var friendScores: [Int]
    }

    struct Friend: Decodable { var name: String; var handicap: Int? }
    struct Wind: Decodable { var fromDeg: Double; var speed: Double; var temperatureC: Double }

    var courseId: String
    var friends: [Friend]
    var holes: [HoleScript]
    /// Simulated walking speed (fast-forwarded) m/s.
    var walkSpeed: Double
    var clubs: [String: Double]
    var wind: Wind

    enum Step: Equatable {
        case intro(hole: Int)
        case walk(to: GeoPoint, caption: String)
        case swing(hole: Int, at: GeoPoint)
        case putt(hole: Int, at: GeoPoint)
        case friendScores(hole: Int)
        case nextHole(Int)
        case pause(Double, caption: String)
        case finish
    }

    static func load(bundle: Bundle = .main) -> ShowcaseScript? {
        guard let url = bundle.url(forResource: "showcase_round", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ShowcaseScript.self, from: data)
    }

    var demoProfile: ClubProfile {
        var out: [Club: ClubProfile.Stats] = [:]
        for (k, v) in clubs {
            guard let club = Club(rawValue: k) else { continue }
            out[club] = ClubProfile.Stats(count: 8, median: v, p25: v - 8, p75: v + 8, longest: v + 15)
        }
        return ClubProfile(clubs: out)
    }

    /// Builds the step list for the given course (holes without tee / green are skipped).
    func steps(course: Course) -> [Step] {
        var out: [Step] = []
        let playable = holes.filter { course.hole($0.number).map(HoleFlyover.canPlay) ?? false }
        for (i, h) in playable.enumerated() {
            guard let hole = course.hole(h.number), let green = hole.effectiveGreenCenter else { continue }
            let line = hole.aimLine
            let length = zip(line, line.dropFirst()).reduce(0) { $0 + Geo.distance($1.0, $1.1) }
            if i > 0 { out.append(.nextHole(h.number)) }
            out.append(.intro(hole: h.number))
            for (k, f) in h.shots.enumerated() {
                let base = Geo.point(along: line, meters: length * f) ?? line[0]
                let ahead = Geo.point(along: line, meters: min(length, length * f + 5)) ?? green
                let lat = k < h.lateral.count ? h.lateral[k] : 0
                let spot = Geo.destination(from: base, bearing: Geo.bearing(base, ahead) + 90, meters: lat)
                if k > 0 { out.append(.walk(to: spot, caption: "走到落點，距離即時更新")) }
                out.append(.swing(hole: h.number, at: spot))
            }
            let puttSpot = Geo.destination(from: green, bearing: 200, meters: 6)
            out.append(.walk(to: puttSpot, caption: "上果嶺"))
            for p in 0..<h.putts {
                let at = p == 0 ? puttSpot : Geo.destination(from: green, bearing: 200, meters: 0.8)
                out.append(.putt(hole: h.number, at: at))
            }
            out.append(.friendScores(hole: h.number))
        }
        out.append(.pause(0.8, caption: ""))
        out.append(.finish)
        return out
    }

    /// Hand-made hole for previews / onboarding when no course is loaded.
    static var demoHole: Hole {
        let o = GeoPoint(lat: 25.0, lon: 121.5)
        func at(_ x: Double, _ y: Double) -> GeoPoint { Geo.unproject(x: x, y: y, origin: o) }
        let green: Polygon = (0..<12).map { i in
            let a = Double(i) / 12 * 2 * .pi
            return at(10 + 14 * sin(a), 360 + 17 * cos(a))
        }
        let fairway = [at(-22, 160), at(18, 150), at(32, 230), at(24, 330), at(-4, 335), at(-20, 250)]
        let bunker = (0..<8).map { i -> GeoPoint in
            let a = Double(i) / 8 * 2 * .pi
            return at(36 + 8 * sin(a), 352 + 6 * cos(a))
        }
        let water = [at(-60, 190), at(-30, 185), at(-28, 240), at(-58, 252)]
        return Hole(number: 1, par: 4, handicap: 5, tee: o, greenCenter: at(10, 360), green: green,
                    path: [o, at(5, 220), at(10, 360)],
                    features: [Feature(kind: .fairway, polygon: fairway), Feature(kind: .green, polygon: green),
                               Feature(kind: .bunker, polygon: bunker), Feature(kind: .water, polygon: water)])
    }

    static var demoCourse: Course {
        var holes: [Hole] = []
        for n in 1...3 {
            var h = demoHole
            h.number = n
            h.par = [4, 5, 3][n - 1]
            holes.append(h)
        }
        return Course(id: "showcase-demo", name: "展示球場", county: "台灣", center: demoHole.effectiveTee ?? GeoPoint(lat: 25, lon: 121.5),
                      holes: holes, source: .featured, provenance: .survey)
    }
}
