import GolfKit
import MapKit
import SwiftUI

enum HoleCamera {
    /// Oblique camera looking from the tee toward the green.
    static func camera(for hole: Hole) -> MapCamera? {
        let tee = hole.effectiveTee
        let green = hole.effectiveGreenCenter
        switch (tee, green) {
        case let (t?, g?):
            let center = Geo.midpoint(t, g)
            let length = hole.lengthMeters ?? Geo.distance(t, g)
            let distance = max(length * MapStyleConfig.distanceFactor, MapStyleConfig.minDistance)
            return MapCamera(
                centerCoordinate: center.coordinate, distance: distance,
                heading: Geo.bearing(t, g), pitch: MapStyleConfig.pitch)
        case let (p?, nil), let (nil, p?):
            return MapCamera(
                centerCoordinate: p.coordinate, distance: MapStyleConfig.singlePointDistance,
                heading: 0, pitch: MapStyleConfig.pitch)
        case (nil, nil):
            return nil
        }
    }

    /// Top-down camera over the course center, used when there is no hole data.
    static func fallbackCamera(for course: Course) -> MapCamera {
        MapCamera(
            centerCoordinate: course.center.coordinate, distance: MapStyleConfig.noDataDistance,
            heading: 0, pitch: 0)
    }
}
