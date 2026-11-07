import Foundation

public struct Hole: Sendable, Codable, Equatable, Hashable {
    public var number: Int
    public var par: Int?
    public var handicap: Int?
    public var tee: GeoPoint?
    public var greenCenter: GeoPoint?
    public var green: Polygon?
    public var path: [GeoPoint]
    public var features: [Feature]

    public init(
        number: Int,
        par: Int? = nil,
        handicap: Int? = nil,
        tee: GeoPoint? = nil,
        greenCenter: GeoPoint? = nil,
        green: Polygon? = nil,
        path: [GeoPoint] = [],
        features: [Feature] = []
    ) {
        self.number = number
        self.par = par
        self.handicap = handicap
        self.tee = tee
        self.greenCenter = greenCenter
        self.green = green
        self.path = path
        self.features = features
    }

    private enum CodingKeys: String, CodingKey {
        case number, par, handicap, tee, greenCenter, green, path, features
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        number = try c.decode(Int.self, forKey: .number)
        par = try c.decodeIfPresent(Int.self, forKey: .par)
        handicap = try c.decodeIfPresent(Int.self, forKey: .handicap)
        tee = try c.decodeIfPresent(GeoPoint.self, forKey: .tee)
        greenCenter = try c.decodeIfPresent(GeoPoint.self, forKey: .greenCenter)
        green = try c.decodeIfPresent(Polygon.self, forKey: .green)
        path = try c.decodeIfPresent([GeoPoint].self, forKey: .path) ?? []
        features = try c.decodeIfPresent([Feature].self, forKey: .features) ?? []
    }

    /// Explicit green center, else centroid of the green polygon, else last path point.
    public var effectiveGreenCenter: GeoPoint? {
        if let greenCenter { return greenCenter }
        if let green, let c = PolygonOps.centroid(green) { return c }
        return path.last
    }

    /// Explicit tee, else first path point.
    public var effectiveTee: GeoPoint? {
        tee ?? path.first
    }

    /// Hole length: along the path if available, else straight tee to green.
    public var lengthMeters: Double? {
        if path.count >= 2 {
            return zip(path, path.dropFirst()).reduce(0) { $0 + Geo.distance($1.0, $1.1) }
        }
        if let t = effectiveTee, let g = effectiveGreenCenter {
            return Geo.distance(t, g)
        }
        return nil
    }
}
