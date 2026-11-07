import Testing
import Foundation
@testable import GolfKit

struct RoundExportTests {
    let rid = UUID()
    let amy = Player(name: "Amy", handicap: 12)

    var events: [RoundEvent] {
        [V2.ev(rid, 0, .start(courseId: "c")), V2.ev(rid, 1, .addPlayer(amy)),
         V2.ev(rid, 2, .setPar(hole: 1, par: 4)),
         V2.ev(rid, 3, .stroke(hole: 1, type: .swing, location: V2.at(0, 0), swing: nil)),
         V2.ev(rid, 4, .stroke(hole: 1, type: .putt, location: nil, swing: nil)),
         V2.ev(rid, 5, .playerScore(playerId: amy.id, hole: 1, strokes: 5, putts: 2)),
         V2.ev(rid, 6, .end)]
    }

    @Test func roundTripAndViewerImport() throws {
        let export = RoundExport.make(events: events, course: nil, courseId: "c", courseName: "Test")
        let back = try RoundExport.decode(export.encode())
        #expect(back.players.count == 2)
        let mine = try back.eventsForViewer(amy.id, course: nil)
        let s = RoundReducer.reduce(mine, course: nil)
        #expect(s.roundId == back.importedRoundId(viewer: amy.id))
        #expect(s.owner.name == "Amy")
        #expect(s.totalStrokes == 5)
        #expect(s.hole(1)?.putts == 2)
        #expect(s.isEnded)
        #expect(s.isManualEntry)
        // Original owner becomes a friend with their whole-hole score.
        let friend = try #require(s.players.first { !$0.isOwner })
        #expect(s.total(for: friend.id) == 2)
    }

    @Test func importIsDeterministic() throws {
        let export = RoundExport.make(events: events, course: nil, courseId: "c", courseName: "Test")
        let a = try export.eventsForViewer(amy.id, course: nil)
        let b = try export.eventsForViewer(amy.id, course: nil)
        #expect(a == b)
        #expect(Set(a.map(\.id)).count == a.count)
        #expect(export.importedRoundId(viewer: amy.id) != export.importedRoundId(viewer: Player.ownerId))
    }

    @Test func errors() {
        #expect(throws: RoundExport.ExportError.corrupted) { try RoundExport.decode(Data("{}".utf8)) }
        let export = RoundExport.make(events: events, course: nil, courseId: "c", courseName: "Test")
        #expect(throws: RoundExport.ExportError.unknownPlayer) { try export.eventsForViewer(UUID(), course: nil) }
    }
}
