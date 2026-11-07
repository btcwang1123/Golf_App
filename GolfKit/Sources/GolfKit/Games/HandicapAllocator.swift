import Foundation

/// Distributes handicap strokes over holes.
public enum HandicapAllocator {
    /// Strokes received on one hole.
    /// - Parameters:
    ///   - holeHandicap: stroke index 1 (hardest)...holeCount; when nil, strokes are spread evenly by `holeNumber`.
    public static func strokes(handicap: Int, holeHandicap: Int?, holeCount: Int, holeNumber: Int = 1) -> Int {
        let n = max(holeCount, 1)
        let h = max(handicap, 0)
        let base = h / n
        let extra = h % n
        guard extra > 0 else { return base }
        if let idx = holeHandicap {
            // Stroke indexes may run 1...18 on a 9-hole loop; map to rank within n.
            let rank = idx > n ? Int((Double(idx) * Double(n) / 18).rounded(.up)) : idx
            return base + (rank <= extra ? 1 : 0)
        }
        let k = min(max(holeNumber, 1), n)
        let gets = (k * extra) / n > ((k - 1) * extra) / n
        return base + (gets ? 1 : 0)
    }

    /// True when the course lacks hole handicaps, so strokes are spread by hole number.
    public static func usesEvenSpread(course: Course?) -> Bool {
        guard let course, !course.holes.isEmpty else { return true }
        return course.holes.contains { $0.handicap == nil }
    }
}
