import Foundation

/// Minimal Codable model of an Overpass API `out geom` JSON response.
public struct OverpassResponse: Sendable, Codable, Equatable {
    public var elements: [OverpassElement]

    public init(elements: [OverpassElement] = []) {
        self.elements = elements
    }

    public static func decode(from data: Data) throws -> OverpassResponse {
        try JSONDecoder().decode(OverpassResponse.self, from: data)
    }
}

public struct OverpassCoordinate: Sendable, Codable, Equatable {
    public var lat: Double
    public var lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    public var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
}

public struct OverpassBounds: Sendable, Codable, Equatable {
    public var minlat: Double
    public var minlon: Double
    public var maxlat: Double
    public var maxlon: Double
}

public struct OverpassMember: Sendable, Codable, Equatable {
    public var type: String
    public var ref: Int64
    public var role: String?
    public var geometry: [OverpassCoordinate]?
}

public struct OverpassElement: Sendable, Codable, Equatable {
    public enum ElementType: String, Sendable, Codable, Equatable {
        case node, way, relation
    }

    public var type: ElementType
    public var id: Int64
    public var tags: [String: String]?
    /// Nodes only.
    public var lat: Double?
    public var lon: Double?
    public var bounds: OverpassBounds?
    /// Ways (and relations flattened by some servers) with `out geom`.
    public var geometry: [OverpassCoordinate]?
    public var members: [OverpassMember]?

    public init(
        type: ElementType,
        id: Int64,
        tags: [String: String]? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        bounds: OverpassBounds? = nil,
        geometry: [OverpassCoordinate]? = nil,
        members: [OverpassMember]? = nil
    ) {
        self.type = type
        self.id = id
        self.tags = tags
        self.lat = lat
        self.lon = lon
        self.bounds = bounds
        self.geometry = geometry
        self.members = members
    }

    public func tag(_ key: String) -> String? { tags?[key] }
}
