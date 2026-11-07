import Foundation

/// A building footprint near a course (OSM), drawn as a low-poly block on the hole map for orientation.
public struct Building: Sendable, Codable, Equatable, Hashable {
    /// Outer ring, not closed (first point is not repeated).
    public var footprint: Polygon
    /// Height in meters.
    public var height: Double

    public init(footprint: Polygon, height: Double) {
        self.footprint = footprint
        self.height = height
    }

    // Compact JSON: {"h": 9, "p": [lat, lon, lat, lon, ...]} with 6 decimals.
    private enum CodingKeys: String, CodingKey { case h, p }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        height = try c.decode(Double.self, forKey: .h)
        let flat = try c.decode([Double].self, forKey: .p)
        footprint = stride(from: 0, to: flat.count - 1, by: 2).map { GeoPoint(lat: flat[$0], lon: flat[$0 + 1]) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode((height * 10).rounded() / 10, forKey: .h)
        try c.encode(footprint.flatMap { [($0.lat * 1e6).rounded() / 1e6, ($0.lon * 1e6).rounded() / 1e6] }, forKey: .p)
    }
}

/// Buildings per course id (`buildings_tw.json`).
public enum BuildingIndex {
    public static func decode(from data: Data) throws -> [String: [Building]] {
        try JSONDecoder().decode([String: [Building]].self, from: data)
    }

    public static func encode(_ index: [String: [Building]]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(index)
    }
}
