import GolfKit
import MapKit
import SwiftUI

/// 100 / 150 / 200 (yd or m) arcs centred on the player, facing the green.
struct DistanceArcsOverlay: MapContent {
    let origin: GeoPoint
    let facing: GeoPoint
    let radii: [Double]
    let labels: [String]
    /// Arcs beyond this distance are not drawn.
    let maxRadius: Double

    var body: some MapContent {
        let bearing = Geo.bearing(origin, facing)
        ForEach(Array(radii.enumerated()), id: \.offset) { i, r in
            if r < maxRadius {
                MapPolyline(coordinates: Self.arc(origin: origin, bearing: bearing, radius: r).map(\.coordinate))
                    .stroke(Theme.ivory.opacity(0.55), style: StrokeStyle(lineWidth: MapStyleConfig.arcLineWidth, dash: [4, 4]))
                Annotation("", coordinate: Geo.destination(from: origin, bearing: bearing + MapStyleConfig.arcHalfAngle, meters: r).coordinate) {
                    MapDistanceLabel(text: labels[i])
                }
            }
        }
    }

    static func arc(origin: GeoPoint, bearing: Double, radius: Double) -> [GeoPoint] {
        let n = MapStyleConfig.arcSegments
        let half = MapStyleConfig.arcHalfAngle
        return (0...n).map { i in
            let b = bearing - half + 2 * half * Double(i) / Double(n)
            return Geo.destination(from: origin, bearing: b, meters: radius)
        }
    }
}
