import Foundation

public struct Course: Sendable, Codable, Equatable, Hashable, Identifiable {
    public enum Source: String, Sendable, Codable, Equatable, Hashable {
        case osm, user, featured
    }

    /// Where the geometry came from. Only `.osm`, `.survey` and `.licensed` may be bundled.
    public enum Provenance: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
        case osm, survey, licensed, userTraced

        public var isDistributable: Bool { self != .userTraced }
    }

    public var id: String
    public var name: String
    public var county: String?
    public var center: GeoPoint
    public var holes: [Hole]
    public var features: [Feature]
    public var source: Source
    public var provenance: Provenance?
    /// OSM course id this course supersedes (featured courses).
    public var replaces: String?

    public init(
        id: String,
        name: String,
        county: String? = nil,
        center: GeoPoint,
        holes: [Hole] = [],
        features: [Feature] = [],
        source: Source = .osm,
        provenance: Provenance? = nil,
        replaces: String? = nil
    ) {
        self.id = id
        self.name = name
        self.county = county
        self.center = center
        self.holes = holes
        self.features = features
        self.source = source
        self.provenance = provenance
        self.replaces = replaces
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, county, center, holes, features, source, provenance, replaces
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        county = try c.decodeIfPresent(String.self, forKey: .county)
        center = try c.decode(GeoPoint.self, forKey: .center)
        holes = try c.decodeIfPresent([Hole].self, forKey: .holes) ?? []
        features = try c.decodeIfPresent([Feature].self, forKey: .features) ?? []
        source = (try? c.decodeIfPresent(Source.self, forKey: .source)) ?? .osm
        provenance = try? c.decodeIfPresent(Provenance.self, forKey: .provenance)
        replaces = try c.decodeIfPresent(String.self, forKey: .replaces)
    }

    /// Effective provenance: explicit, else inferred from `source`.
    public var effectiveProvenance: Provenance {
        provenance ?? (source == .user ? .userTraced : .osm)
    }

    public func hole(_ number: Int) -> Hole? {
        holes.first { $0.number == number }
    }

    /// True when any hole has tee or green data.
    public var hasHoleMaps: Bool {
        holes.contains { $0.effectiveTee != nil || $0.effectiveGreenCenter != nil }
    }

    public static func decodeList(from data: Data) throws -> [Course] {
        try JSONDecoder().decode([Course].self, from: data)
    }

    public static func encodeList(_ courses: [Course]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(courses)
    }
}
