import Foundation

/// A WGS84 coordinate. Encoded with 6 decimal places to keep JSON small.
public struct GeoPoint: Sendable, Codable, Equatable, Hashable {
    public var lat: Double
    public var lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    private enum CodingKeys: String, CodingKey { case lat, lon }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lat = try c.decode(Double.self, forKey: .lat)
        lon = try c.decode(Double.self, forKey: .lon)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.round6(lat), forKey: .lat)
        try c.encode(Self.round6(lon), forKey: .lon)
    }

    private static func round6(_ v: Double) -> Double {
        (v * 1_000_000).rounded() / 1_000_000
    }
}

public typealias Polygon = [GeoPoint]
