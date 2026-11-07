import Foundation

public struct DispersionPoint: Sendable, Codable, Equatable, Hashable {
    /// Meters forward along shot → target.
    public var along: Double
    /// Meters right (+) / left (−) of that line.
    public var lateral: Double

    public init(along: Double, lateral: Double) {
        self.along = along
        self.lateral = lateral
    }
}

public enum DispersionStats {
    /// Landing position relative to the start → target line.
    public static func relative(shot: GeoPoint, next: GeoPoint, target: GeoPoint) -> DispersionPoint {
        let t = Geo.project(target, origin: shot)
        let n = Geo.project(next, origin: shot)
        let len = (t.x * t.x + t.y * t.y).squareRoot()
        guard len > 1e-6 else { return DispersionPoint(along: (n.x * n.x + n.y * n.y).squareRoot(), lateral: 0) }
        let ux = t.x / len, uy = t.y / len
        return DispersionPoint(along: n.x * ux + n.y * uy, lateral: n.x * uy - n.y * ux)
    }

    /// Left/right miss in meters, right positive.
    public static func lateral(shot: GeoPoint, next: GeoPoint, target: GeoPoint) -> Double {
        relative(shot: shot, next: next, target: target).lateral
    }
}
