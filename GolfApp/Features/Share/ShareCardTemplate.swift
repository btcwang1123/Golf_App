import GolfKit
import SwiftUI

enum ShareCardTemplate: String, CaseIterable, Identifiable {
    case story, square, scorecard
    var id: String { rawValue }

    var title: String {
        switch self {
        case .story: "限時動態"
        case .square: "方形"
        case .scorecard: "計分卡"
        }
    }

    /// Output pixels.
    var pixelSize: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .square: CGSize(width: 1080, height: 1080)
        case .scorecard: CGSize(width: 1080, height: 1350)
        }
    }

    static let renderScale: CGFloat = 3
    /// Layout size in points (pixels / scale).
    var pointSize: CGSize { CGSize(width: pixelSize.width / Self.renderScale, height: pixelSize.height / Self.renderScale) }
}

/// Everything a share card shows. Built outside the view so `body` stays free of logic.
struct ShareCardData {
    let courseName: String
    let date: Date
    let total: Int
    let toPar: Int?
    let holeCount: Int
    let highlights: RoundHighlights
    let holes: [HoleState]
    let featuredHole: Hole?
    let course: Course?
    let standings: [(name: String, total: Int, detail: String)]
    let players: [Player]
    let round: RoundState
    let shareURL: String
    let settings: AppSettings

    init(round: RoundState, course: Course?, courseName: String, settings: AppSettings) {
        self.round = round
        self.course = course
        self.courseName = courseName
        self.date = round.startedAt ?? Date()
        self.total = round.totalStrokes
        self.toPar = round.toPar
        let last = round.holes.filter { $0.total > 0 }.map(\.number).max() ?? 0
        let count = (course?.holes.count).flatMap { $0 > 0 ? $0 : nil } ?? (last <= 9 ? 9 : 18)
        self.holeCount = last <= 9 && count >= 9 ? 9 : count
        self.highlights = RoundHighlights(state: round, holeCount: holeCount)
        self.holes = (1...max(holeCount, 1)).map { round.hole($0) ?? HoleState(number: $0) }
        let best = highlights.bestHole.flatMap { course?.hole($0) }
        self.featuredHole = [best, course?.holes.first].compactMap { $0 }.first { HoleQuality.evaluate($0).isPlayable }
        self.players = round.players
        if round.players.count > 1 {
            standings = GameScorer.standings(state: round, course: course).map { s in
                (round.players.first { $0.id == s.playerId }?.name ?? "", s.gross, s.detail)
            }
        } else {
            standings = []
        }
        self.shareURL = settings.shareURL
        self.settings = settings
    }
}
