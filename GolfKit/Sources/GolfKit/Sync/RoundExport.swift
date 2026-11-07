import Foundation

/// `.golfround` file shared with the playing group.
public struct RoundExport: Sendable, Codable, Equatable {
    public static let currentVersion = 1
    public static let fileExtension = "golfround"

    public enum ExportError: Error, Equatable, LocalizedError {
        case corrupted
        case unsupportedVersion(Int)
        case unknownPlayer

        public var errorDescription: String? {
            switch self {
            case .corrupted: "檔案已損毀或不是回合資料。"
            case .unsupportedVersion(let v): "此檔案版本（v\(v)）需要較新的 App。"
            case .unknownPlayer: "找不到選擇的球員。"
            }
        }
    }

    public var version: Int
    public var roundId: UUID
    public var events: [RoundEvent]
    public var players: [Player]
    public var courseId: String
    public var courseName: String
    public var viewerPlayerId: UUID?

    public init(version: Int = RoundExport.currentVersion, roundId: UUID, events: [RoundEvent], players: [Player],
                courseId: String, courseName: String, viewerPlayerId: UUID? = nil) {
        self.version = version
        self.roundId = roundId
        self.events = events
        self.players = players
        self.courseId = courseId
        self.courseName = courseName
        self.viewerPlayerId = viewerPlayerId
    }

    public static func make(events: [RoundEvent], course: Course?, courseId: String, courseName: String) -> RoundExport {
        let state = RoundReducer.reduce(events, course: course)
        return RoundExport(roundId: state.roundId, events: events, players: state.players,
                           courseId: courseId, courseName: courseName)
    }

    public func encode() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> RoundExport {
        struct Header: Decodable { var version: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw ExportError.corrupted }
        guard header.version >= 1, header.version <= currentVersion else { throw ExportError.unsupportedVersion(header.version) }
        do { return try JSONDecoder().decode(RoundExport.self, from: data) } catch { throw ExportError.corrupted }
    }

    /// Deterministic id of the imported copy, so importing the same file twice is idempotent.
    public func importedRoundId(viewer: UUID) -> UUID {
        var bytes = Array(withUnsafeBytes(of: roundId.uuid) { Data($0) })
        let v = Array(withUnsafeBytes(of: viewer.uuid) { Data($0) })
        for i in 0..<16 { bytes[i] ^= v[i] }
        bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Events for a new round seen from `viewer`: their whole-hole scores as the owner's strokes,
    /// everyone else as friends. No stroke-level GPS.
    public func eventsForViewer(_ viewer: UUID, course: Course?) throws -> [RoundEvent] {
        let state = RoundReducer.reduce(events, course: course)
        guard let me = state.players.first(where: { $0.id == viewer }) else { throw ExportError.unknownPlayer }
        let newId = importedRoundId(viewer: viewer)
        var t = state.startedAt ?? events.first?.timestamp ?? Date()
        var out: [RoundEvent] = []
        var counter: UInt8 = 0
        func add(_ kind: RoundEvent.Kind) {
            // Deterministic ids keep re-imports stable.
            counter &+= 1
            var b = Array(withUnsafeBytes(of: newId.uuid) { Data($0) })
            b[15] = b[15] &+ counter
            b[14] = b[14] &+ UInt8(truncatingIfNeeded: out.count >> 8)
            let id = UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
            out.append(RoundEvent(id: id, roundId: newId, timestamp: t, source: .phone, kind: kind))
            t = t.addingTimeInterval(1)
        }
        add(.start(courseId: courseId))
        add(.addPlayer(Player(id: Player.ownerId, name: me.name, handicap: me.handicap, isOwner: true)))
        for p in state.players where p.id != viewer {
            add(.addPlayer(Player(id: p.isOwner ? state.roundId : p.id, name: p.name, handicap: p.handicap, isOwner: false)))
        }
        if state.game != .stroke { add(.setGame(state.game)) }
        let numbers = Set(state.players.flatMap { state.scores(for: $0.id).keys }).sorted()
        for n in numbers {
            if let par = state.hole(n)?.par { add(.setPar(hole: n, par: par)) }
            if let mine = state.scores(for: viewer)[n] {
                let putts = min(mine.putts ?? 0, mine.strokes)
                for _ in 0..<(mine.strokes - putts) { add(.stroke(hole: n, type: .manual, location: nil, swing: nil)) }
                for _ in 0..<putts { add(.stroke(hole: n, type: .putt, location: nil, swing: nil)) }
            }
            for p in state.players where p.id != viewer {
                guard let sc = state.scores(for: p.id)[n] else { continue }
                add(.playerScore(playerId: p.isOwner ? state.roundId : p.id, hole: n, strokes: sc.strokes, putts: sc.putts))
            }
        }
        add(.end)
        return out
    }
}
