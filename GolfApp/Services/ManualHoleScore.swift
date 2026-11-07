import Foundation
import GolfKit

/// One hole of a hand-entered scorecard. `strokes` is the hole total, penalties included.
struct ManualHoleScore: Equatable, Identifiable, Sendable {
    static let parRange = 3...6
    static let strokeRange = 0...15

    var number: Int
    var par: Int
    var strokes: Int = 0
    var putts: Int = 0
    var penalties: Int = 0

    var id: Int { number }
    var isPlayed: Bool { strokes > 0 }
    /// Strokes hit before reaching the green (excludes putts and penalties).
    var fullShots: Int { max(0, strokes - putts - penalties) }

    /// Keeps putts + penalties within the stroke total.
    mutating func clamp() {
        strokes = min(max(strokes, Self.strokeRange.lowerBound), Self.strokeRange.upperBound)
        putts = min(max(putts, 0), strokes)
        penalties = min(max(penalties, 0), strokes - putts)
    }

    /// Encodes a scorecard as round events so it flows through the same reducer as live rounds.
    static func events(roundId: UUID, courseId: String, date: Date, holes: [ManualHoleScore]) -> [RoundEvent] {
        var t = date
        var out: [RoundEvent] = []
        func add(_ kind: RoundEvent.Kind) {
            out.append(RoundEvent(roundId: roundId, timestamp: t, source: .phone, kind: kind))
            t = t.addingTimeInterval(1)
        }
        add(.start(courseId: courseId))
        for hole in holes.sorted(by: { $0.number < $1.number }) {
            add(.setPar(hole: hole.number, par: hole.par))
            guard hole.isPlayed else { continue }
            for _ in 0..<hole.fullShots {
                add(.stroke(hole: hole.number, type: .manual, location: nil, swing: nil))
            }
            for _ in 0..<hole.putts {
                add(.stroke(hole: hole.number, type: .putt, location: nil, swing: nil))
            }
            if hole.penalties > 0 { add(.penalty(hole: hole.number, count: hole.penalties)) }
        }
        add(.end)
        return out
    }

    /// Rebuilds editable scores from a reduced round.
    static func from(state: RoundState, holeCount: Int, defaultPar: (Int) -> Int) -> [ManualHoleScore] {
        (1...max(holeCount, 1)).map { n in
            let h = state.hole(n)
            return ManualHoleScore(
                number: n, par: h?.par ?? defaultPar(n),
                strokes: h?.total ?? 0, putts: h?.putts ?? 0, penalties: h?.penalties ?? 0)
        }
    }

    /// A round is treated as hand-entered when no stroke carries GPS or swing data.
    static func isManual(_ state: RoundState) -> Bool {
        state.holes.allSatisfy { $0.shots.allSatisfy { $0.location == nil && $0.swing == nil } }
    }
}
