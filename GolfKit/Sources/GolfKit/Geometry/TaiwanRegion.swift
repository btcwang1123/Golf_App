import Foundation

/// Coarse region of Taiwan, inferred from coordinates (most OSM courses have no county tag).
public enum TaiwanRegion: String, Sendable, Codable, CaseIterable, Hashable {
    case north, central, south, east, islands

    public var label: String {
        switch self {
        case .north: "北部"
        case .central: "中部"
        case .south: "南部"
        case .east: "東部"
        case .islands: "離島"
        }
    }

    /// Approximate boundaries: Penghu/Kinmen/Matsu west of 120°E; Yilan/Hualien/Taitung on the east side
    /// of the Central Range; north ≈ Hsinchu/Miaoli and up; central down to Yunlin; south from Chiayi.
    public static func of(_ p: GeoPoint) -> TaiwanRegion {
        if p.lon < 120.0 || p.lon > 122.2 || p.lat < 21.85 { return .islands }
        if (p.lat < 24.95 && p.lon > 121.45) || (p.lat < 23.6 && p.lon > 120.95) { return .east }
        if p.lat >= 24.5 { return .north }
        if p.lat >= 23.55 { return .central }
        return .south
    }
}
