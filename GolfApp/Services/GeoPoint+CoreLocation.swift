import CoreLocation
import GolfKit

extension GeoPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    init(_ c: CLLocationCoordinate2D) {
        self.init(lat: c.latitude, lon: c.longitude)
    }
}
