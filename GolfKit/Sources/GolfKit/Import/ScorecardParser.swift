import Foundation

/// A piece of recognized text with its normalized bounding box (0–1, origin top-left).
public struct OCRToken: Sendable, Equatable {
    public var text: String
    public var minX: Double
    public var maxX: Double
    public var midY: Double
    public var height: Double

    public init(text: String, minX: Double, maxX: Double, midY: Double, height: Double) {
        self.text = text
        self.minX = minX
        self.maxX = maxX
        self.midY = midY
        self.height = height
    }
}

/// Table read from a photographed paper scorecard.
public struct ParsedScorecard: Sendable, Equatable {
    public struct Row: Sendable, Equatable, Identifiable {
        public var id: Int
        public var label: String?
        /// Hole number → value.
        public var scores: [Int: Int]

        public var total: Int { scores.values.reduce(0, +) }
    }

    public var holes: [Int]
    public var pars: [Int: Int]
    /// Candidate player rows, top to bottom.
    public var rows: [Row]
}

/// Heuristic reader for printed scorecards: finds the hole-number row, then the par row and score rows aligned to it.
public enum ScorecardParser {
    static let parLabels = ["PAR", "標準", "標準桿"]
    static let skipLabels = ["HCP", "HDCP", "HANDICAP", "差點", "難度", "INDEX", "YARD", "YDS", "碼", "METER", "公尺", "TEE"]

    struct Number { var value: Int; var x: Double }
    struct Line { var y: Double; var numbers: [Number]; var label: String? }

    public static func parse(_ tokens: [OCRToken]) -> ParsedScorecard? {
        let lines = groupLines(tokens)
        // Hole rows: contain most of 1...9 or 10...18 in left-to-right order.
        var sections: [(lineIndex: Int, columns: [(hole: Int, x: Double)])] = []
        for (i, line) in lines.enumerated() {
            if let cols = holeColumns(line) { sections.append((i, cols)) }
        }
        guard !sections.isEmpty else { return nil }

        var holes: [Int] = []
        var pars: [Int: Int] = [:]
        var rowsBySection: [[ParsedScorecard.Row]] = []
        for (s, section) in sections.enumerated() {
            holes += section.columns.map(\.hole)
            let end = s + 1 < sections.count ? sections[s + 1].lineIndex : lines.count
            let spacing = columnSpacing(section.columns)
            var rows: [ParsedScorecard.Row] = []
            var foundPar = false
            for li in (section.lineIndex + 1)..<end {
                let line = lines[li]
                let assigned = assign(line.numbers, to: section.columns, tolerance: spacing * 0.45)
                guard Double(assigned.count) >= Double(section.columns.count) * 0.5 else { continue }
                let label = line.label?.uppercased() ?? ""
                if skipLabels.contains(where: { label.contains($0) }) { continue }
                let values = Array(assigned.values)
                // Unlabelled par rows: only 3–5 with mostly 4s.
                let looksLikePar = values.allSatisfy { (3...5).contains($0) } && values.filter { $0 == 4 }.count * 3 >= values.count
                if !foundPar, parLabels.contains(where: { label.contains($0) }) || (looksLikePar && rows.isEmpty) {
                    for (h, v) in assigned where (3...6).contains(v) { pars[h] = v }
                    foundPar = true
                    continue
                }
                // Distance rows (yards / meters) and stroke-index rows are not scores.
                if values.contains(where: { $0 > 15 }) || values.contains(0) { continue }
                rows.append(ParsedScorecard.Row(id: rows.count, label: line.label, scores: assigned))
            }
            rowsBySection.append(rows)
        }
        // Merge sections row by row (front nine row k + back nine row k).
        let count = rowsBySection.map(\.count).max() ?? 0
        var merged: [ParsedScorecard.Row] = []
        for k in 0..<count {
            var scores: [Int: Int] = [:]
            var label: String?
            for rows in rowsBySection where rows.indices.contains(k) {
                scores.merge(rows[k].scores) { a, _ in a }
                label = label ?? rows[k].label
            }
            merged.append(ParsedScorecard.Row(id: k, label: label, scores: scores))
        }
        return ParsedScorecard(holes: holes.sorted(), pars: pars, rows: merged)
    }

    /// Splits multi-number tokens and clusters by vertical position.
    static func groupLines(_ tokens: [OCRToken]) -> [Line] {
        struct Piece { var text: String; var x: Double; var y: Double; var h: Double }
        var pieces: [Piece] = []
        for t in tokens {
            let parts = t.text.split(whereSeparator: { $0 == " " || $0 == "|" || $0 == "\t" }).map(String.init)
            guard !parts.isEmpty else { continue }
            let width = (t.maxX - t.minX) / Double(parts.count)
            for (i, p) in parts.enumerated() {
                pieces.append(Piece(text: p, x: t.minX + width * (Double(i) + 0.5), y: t.midY, h: t.height))
            }
        }
        let heights = pieces.map(\.h).sorted()
        let median = heights.isEmpty ? 0.02 : heights[heights.count / 2]
        var lines: [(y: Double, items: [Piece])] = []
        for p in pieces.sorted(by: { $0.y < $1.y }) {
            if let last = lines.indices.last, abs(lines[last].y - p.y) < median * 0.6 {
                lines[last].items.append(p)
                let n = Double(lines[last].items.count)
                lines[last].y = lines[last].y * (n - 1) / n + p.y / n
            } else {
                lines.append((p.y, [p]))
            }
        }
        return lines.map { line in
            let sorted = line.items.sorted { $0.x < $1.x }
            let numbers = sorted.compactMap { p in Int(normalizeDigits(p.text)).map { Number(value: $0, x: p.x) } }
            let label = sorted.first { Int(normalizeDigits($0.text)) == nil }?.text
            return Line(y: line.y, numbers: numbers, label: label)
        }
    }

    /// OCR often confuses digits with letters on scorecards.
    static func normalizeDigits(_ s: String) -> String {
        let map: [Character: Character] = ["O": "0", "o": "0", "l": "1", "I": "1", "|": "1", "S": "5", "B": "8", "Z": "2"]
        let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;()[]"))
        guard trimmed.contains(where: \.isNumber) || trimmed.count == 1 else { return trimmed }
        return String(trimmed.map { map[$0] ?? $0 })
    }

    static func holeColumns(_ line: Line) -> [(hole: Int, x: Double)]? {
        for range in [1...9, 10...18] {
            var cols: [(Int, Double)] = []
            var next = range.lowerBound
            for n in line.numbers where range.contains(n.value) && n.value >= next {
                cols.append((n.value, n.x))
                next = n.value + 1
            }
            if cols.count >= 7 { return fillGaps(cols, range: range) }
        }
        return nil
    }

    /// Interpolates x for hole numbers OCR missed.
    static func fillGaps(_ cols: [(Int, Double)], range: ClosedRange<Int>) -> [(hole: Int, x: Double)] {
        guard cols.count >= 2 else { return cols.map { ($0.0, $0.1) } }
        let slope = (cols.last!.1 - cols.first!.1) / Double(cols.last!.0 - cols.first!.0)
        let known = Dictionary(cols, uniquingKeysWith: { a, _ in a })
        return range.map { h in (h, known[h] ?? cols.first!.1 + slope * Double(h - cols.first!.0)) }
    }

    static func columnSpacing(_ cols: [(hole: Int, x: Double)]) -> Double {
        guard cols.count >= 2 else { return 0.05 }
        return (cols.last!.x - cols.first!.x) / Double(cols.count - 1)
    }

    static func assign(_ numbers: [Number], to cols: [(hole: Int, x: Double)], tolerance: Double) -> [Int: Int] {
        var out: [Int: Int] = [:]
        var bestDist: [Int: Double] = [:]
        for n in numbers {
            guard let c = cols.min(by: { abs($0.x - n.x) < abs($1.x - n.x) }) else { continue }
            let d = abs(c.x - n.x)
            guard d <= tolerance, d < (bestDist[c.hole] ?? .infinity) else { continue }
            out[c.hole] = n.value
            bestDist[c.hole] = d
        }
        return out
    }
}
