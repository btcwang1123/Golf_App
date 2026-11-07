import Foundation

/// Share of holes by score relative to par.
public struct ScoringBreakdown: Sendable, Codable, Equatable, Hashable {
    public enum Bucket: String, Sendable, Codable, CaseIterable, Hashable {
        case eagle, birdie, par, bogey, doublePlus

        public var title: String {
            switch self {
            case .eagle: "老鷹+"
            case .birdie: "博蒂"
            case .par: "平標準"
            case .bogey: "柏忌"
            case .doublePlus: "雙柏忌+"
            }
        }

        public init(diff: Int) {
            switch diff {
            case ...(-2): self = .eagle
            case -1: self = .birdie
            case 0: self = .par
            case 1: self = .bogey
            default: self = .doublePlus
            }
        }
    }

    public var counts: [Bucket: Int]

    public init(counts: [Bucket: Int] = [:]) {
        self.counts = counts
    }

    public var total: Int { counts.values.reduce(0, +) }

    public func share(_ b: Bucket) -> Double {
        total > 0 ? Double(counts[b] ?? 0) / Double(total) : 0
    }

    public mutating func add(strokes: Int, par: Int) {
        counts[Bucket(diff: strokes - par), default: 0] += 1
    }
}
