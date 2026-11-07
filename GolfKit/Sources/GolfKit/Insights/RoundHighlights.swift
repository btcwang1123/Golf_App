import Foundation

/// Share-card highlights of one round.
public struct RoundHighlights: Sendable, Equatable {
    public var birdiesOrBetter: Int
    public var pars: Int
    public var longestShot: (meters: Double, club: Club?)?
    public var fewestPuttsHole: (hole: Int, putts: Int)?
    /// Best hole relative to par (lowest number on ties).
    public var bestHole: Int?
    public var front: Int
    public var back: Int

    public static func == (a: RoundHighlights, b: RoundHighlights) -> Bool {
        a.birdiesOrBetter == b.birdiesOrBetter && a.pars == b.pars && a.bestHole == b.bestHole
            && a.front == b.front && a.back == b.back
            && a.longestShot?.meters == b.longestShot?.meters && a.fewestPuttsHole?.hole == b.fewestPuttsHole?.hole
    }

    public init(state: RoundState, holeCount: Int? = nil) {
        let played = state.holes.filter { $0.total > 0 }
        var birdies = 0, pars = 0
        for h in played { if let p = h.par { if h.total < p { birdies += 1 } else if h.total == p { pars += 1 } } }
        birdiesOrBetter = birdies
        self.pars = pars
        let shots = played.flatMap(\.shots).filter { $0.type != .putt && ClubProfile.validRange.contains($0.distanceToNext ?? 0) }
        longestShot = shots.max { ($0.distanceToNext ?? 0) < ($1.distanceToNext ?? 0) }.map { ($0.distanceToNext ?? 0, $0.club) }
        let withPutts = played.filter { $0.putts > 0 }
        fewestPuttsHole = withPutts.min { $0.putts == $1.putts ? $0.number < $1.number : $0.putts < $1.putts }.map { ($0.number, $0.putts) }
        bestHole = played.filter { $0.par != nil }
            .min { a, b in
                let da = a.total - (a.par ?? 0), db = b.total - (b.par ?? 0)
                return da == db ? a.number < b.number : da < db
            }?.number
        let n = holeCount ?? max(state.holes.count, 1)
        let half = n > 9 ? (n + 1) / 2 : n
        front = state.holes.filter { $0.number <= half }.reduce(0) { $0 + $1.total }
        back = state.holes.filter { $0.number > half }.reduce(0) { $0 + $1.total }
    }
}
