import GolfKit
import MapKit
import SwiftUI

/// Camera path for the hole intro: behind the tee → landing zone → over the green → whole hole.
enum HoleFlyover {
    /// Seconds per leg; total ≈ 4 s.
    static let legDurations: [Double] = [0.0, 1.4, 1.3, 1.3]

    static func keyframes(for hole: Hole) -> [MapCamera] {
        guard let tee = hole.effectiveTee, let green = hole.effectiveGreenCenter,
              let overview = HoleCamera.camera(for: hole) else { return [] }
        let bearing = Geo.bearing(tee, green)
        let length = hole.lengthMeters ?? Geo.distance(tee, green)
        let behindTee = Geo.destination(from: tee, bearing: bearing + 180, meters: 40)
        let landing = Geo.point(along: hole.aimLine, meters: min(length * 0.6, 230)) ?? Geo.midpoint(tee, green)
        return [
            MapCamera(centerCoordinate: Geo.destination(from: behindTee, bearing: bearing, meters: 80).coordinate,
                      distance: 260, heading: bearing, pitch: 70),
            MapCamera(centerCoordinate: landing.coordinate, distance: 320, heading: bearing, pitch: 62),
            MapCamera(centerCoordinate: green.coordinate, distance: 180, heading: bearing, pitch: 20),
            overview,
        ]
    }

    static func canPlay(_ hole: Hole?) -> Bool {
        hole?.effectiveTee != nil && hole?.effectiveGreenCenter != nil
    }
}

extension View {
    /// Plays the flyover whenever `trigger` changes.
    func holeFlyover(_ frames: [MapCamera], trigger: Int) -> some View {
        mapCameraKeyframeAnimator(trigger: trigger) { initial in
            let f = frames.count == 4 ? frames : [initial, initial, initial, initial]
            let d = HoleFlyover.legDurations
            KeyframeTrack(\MapCamera.centerCoordinate) {
                LinearKeyframe(f[0].centerCoordinate, duration: 0.01)
                CubicKeyframe(f[1].centerCoordinate, duration: d[1])
                CubicKeyframe(f[2].centerCoordinate, duration: d[2])
                CubicKeyframe(f[3].centerCoordinate, duration: d[3])
            }
            KeyframeTrack(\MapCamera.distance) {
                LinearKeyframe(f[0].distance, duration: 0.01)
                CubicKeyframe(f[1].distance, duration: d[1])
                CubicKeyframe(f[2].distance, duration: d[2])
                CubicKeyframe(f[3].distance, duration: d[3])
            }
            KeyframeTrack(\MapCamera.pitch) {
                LinearKeyframe(f[0].pitch, duration: 0.01)
                CubicKeyframe(f[1].pitch, duration: d[1])
                CubicKeyframe(f[2].pitch, duration: d[2])
                CubicKeyframe(f[3].pitch, duration: d[3])
            }
            KeyframeTrack(\MapCamera.heading) {
                LinearKeyframe(f[0].heading, duration: 0.01)
                LinearKeyframe(f[3].heading, duration: d[1] + d[2] + d[3])
            }
        }
    }
}
