import Foundation

public enum LieClassifier {
    /// Within this distance of the tee point counts as `.tee`.
    public static let teeRadius = 12.0

    /// Lie from the hole's feature polygons; `.rough` when nothing covers the point.
    public static func classify(_ p: GeoPoint, hole: Hole) -> Lie {
        if let g = hole.green, PolygonOps.contains(p, in: g) { return .green }
        let fs = hole.features
        func inside(_ kinds: Set<Feature.Kind>) -> Bool {
            fs.contains { kinds.contains($0.kind) && PolygonOps.contains(p, in: $0.polygon) }
        }
        if inside([.green]) { return .green }
        if inside([.bunker]) { return .sand }
        if inside([.water, .lateralWater, .outOfBounds]) { return .recovery }
        if inside([.tee]) { return .tee }
        if let t = hole.effectiveTee, Geo.distance(p, t) <= teeRadius { return .tee }
        if inside([.fairway]) { return .fairway }
        return .rough
    }
}
