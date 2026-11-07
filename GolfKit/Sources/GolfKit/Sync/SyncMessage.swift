import Foundation

/// Messages exchanged between iPhone and Watch over WatchConnectivity.
public enum SyncMessage: Sendable, Codable, Equatable {
    case events([RoundEvent])
    case course(Course)
    case startRound(roundId: UUID, courseId: String)
    case settings(AppSettings)
    case endRound(roundId: UUID)
    case requestCourse(courseId: String)
    /// A finished driving-range session from the watch.
    case practice(PracticeSession)

    /// Dictionary key under which the JSON payload is stored.
    public static let payloadKey = "msg"

    public enum SyncError: Error, Equatable {
        case missingPayload
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(SyncMessage.self, from: data)
    }

    public func encodedDictionary() throws -> [String: Any] {
        [Self.payloadKey: try encoded()]
    }

    public static func decode(from dict: [String: Any]) throws -> SyncMessage {
        guard let data = dict[payloadKey] as? Data else { throw SyncError.missingPayload }
        return try SyncMessage(data: data)
    }
}
