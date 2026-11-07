import Foundation

/// Averages GPS samples to mark a point on the course; discards inaccurate samples.
public struct PointAverager: Sendable, Equatable {
    /// Samples with horizontal accuracy above this (m) are ignored.
    public static let maxSampleAccuracy = 10.0
    /// Average accuracy above this (m) should be re-measured.
    public static let warnAccuracy = 8.0

    public private(set) var samples: [GeoPoint] = []
    public private(set) var accuracies: [Double] = []
    public private(set) var rejected = 0

    public init() {}

    public mutating func add(_ p: GeoPoint, accuracy: Double) {
        guard accuracy >= 0, accuracy <= Self.maxSampleAccuracy else {
            rejected += 1
            return
        }
        samples.append(p)
        accuracies.append(accuracy)
    }

    public mutating func reset() { self = PointAverager() }

    public var count: Int { samples.count }

    /// Mean of accepted samples (accuracy-weighted), nil if none.
    public var result: GeoPoint? {
        guard let origin = samples.first else { return nil }
        var sx = 0.0, sy = 0.0, sw = 0.0
        for (p, acc) in zip(samples, accuracies) {
            let w = 1 / max(acc, 1) / max(acc, 1)
            let q = Geo.project(p, origin: origin)
            sx += q.x * w; sy += q.y * w; sw += w
        }
        return Geo.unproject(x: sx / sw, y: sy / sw, origin: origin)
    }

    /// RMS distance of samples from the mean (m); 0 with fewer than two samples.
    public var spreadMeters: Double {
        guard samples.count >= 2, let c = result else { return 0 }
        let sq = samples.reduce(0) { $0 + pow(Geo.distance($1, c), 2) }
        return (sq / Double(samples.count)).squareRoot()
    }

    /// Mean reported accuracy (m), nil if none.
    public var meanAccuracy: Double? {
        accuracies.isEmpty ? nil : accuracies.reduce(0, +) / Double(accuracies.count)
    }

    /// Estimated error: the larger of mean accuracy and spread.
    public var estimatedError: Double? { meanAccuracy.map { max($0, spreadMeters) } }

    public var needsRetry: Bool { (estimatedError ?? .infinity) > Self.warnAccuracy }
}

/// Turns a walked track around a green into a polygon.
public enum TrackPolygon {
    public static let simplifyMeters = 1.0

    /// Drops jitter, simplifies with 1 m tolerance and closes the ring. Nil when < 3 points remain.
    public static func close(_ track: [GeoPoint], epsilonMeters: Double = simplifyMeters) -> Polygon? {
        var pts = track
        if let f = pts.first, let l = pts.last, pts.count > 2, Geo.distance(f, l) > 0.01 { pts.append(f) }
        var simplified = Simplify.douglasPeucker(pts, epsilonMeters: epsilonMeters)
        if simplified.count > 1, let f = simplified.first, let l = simplified.last, Geo.distance(f, l) < 0.01 {
            simplified.removeLast()
        }
        return simplified.count >= 3 ? simplified : nil
    }
}
