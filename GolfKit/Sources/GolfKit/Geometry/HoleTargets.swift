import Foundation

extension Hole {
    /// Path used for aiming: explicit path, else tee → green.
    public var aimLine: [GeoPoint] {
        if path.count >= 2 { return path }
        return [effectiveTee, effectiveGreenCenter].compactMap { $0 }
    }

    /// Default aim point on the centre line, `carry` meters ahead of the player's progress along the hole.
    /// Nil when the green is within reach (aim at the green instead).
    public func defaultTarget(from position: GeoPoint?, carry: Double) -> GeoPoint? {
        let line = aimLine
        guard line.count >= 2 else { return nil }
        let total = zip(line, line.dropFirst()).reduce(0) { $0 + Geo.distance($1.0, $1.1) }
        let start = position.map { Geo.alongDistance(of: $0, line: line) } ?? 0
        let s = start + carry
        guard s < total - 10 else { return nil }
        return Geo.point(along: line, meters: s)
    }

    /// Front / middle / back pin positions on the green along the tee → green axis.
    /// Front and back sit 35% of the way from the green edge toward the centre.
    public static let pinPresetInset = 0.35

    public func pinPresets() -> (front: GeoPoint, center: GeoPoint, back: GeoPoint)? {
        guard let from = effectiveTee ?? path.first, let g = greenFrontCenterBack(from: from) else { return nil }
        func lerp(_ a: GeoPoint, _ b: GeoPoint, _ t: Double) -> GeoPoint {
            let q = Geo.project(b, origin: a)
            return Geo.unproject(x: q.x * t, y: q.y * t, origin: a)
        }
        return (lerp(g.front, g.center, Self.pinPresetInset), g.center, lerp(g.back, g.center, Self.pinPresetInset))
    }

    /// Distances with an optional pin: center becomes "to the pin"; front / back stay at the green edges.
    public func distancesMeters(from position: GeoPoint, pin: GeoPoint?) -> (front: Double, center: Double, back: Double)? {
        guard var d = greenDistancesMeters(from: position) else {
            return pin.map { let c = Geo.distance(position, $0); return (c, c, c) }
        }
        if let pin { d.center = Geo.distance(position, pin) }
        return d
    }
}

extension Geo {
    /// Distance along `line` to the point on it closest to `p`.
    public static func alongDistance(of p: GeoPoint, line: [GeoPoint]) -> Double {
        guard line.count >= 2 else { return 0 }
        var best = (d: Double.infinity, s: 0.0)
        var acc = 0.0
        for (a, b) in zip(line, line.dropFirst()) {
            let pb = project(b, origin: a), pp = project(p, origin: a)
            let len2 = pb.x * pb.x + pb.y * pb.y
            let t = len2 == 0 ? 0 : min(1, max(0, (pp.x * pb.x + pp.y * pb.y) / len2))
            let ex = pp.x - t * pb.x, ey = pp.y - t * pb.y
            let d = (ex * ex + ey * ey).squareRoot()
            let len = len2.squareRoot()
            if d < best.d { best = (d, acc + t * len) }
            acc += len
        }
        return best.s
    }
}
