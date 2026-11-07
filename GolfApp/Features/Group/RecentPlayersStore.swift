import Foundation
import GolfKit
import Observation

/// Last 10 friends' names and handicaps, kept in UserDefaults for one-tap re-adding.
@MainActor @Observable
final class RecentPlayersStore {
    struct Entry: Codable, Hashable, Identifiable {
        var name: String
        var handicap: Int?
        var id: String { name }
    }

    static let limit = 10
    private static let key = "recentPlayers.v1"

    private(set) var entries: [Entry] = []
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let list = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = list
        }
    }

    func remember(_ players: [Player]) {
        for p in players where !p.isOwner {
            let name = p.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            entries.removeAll { $0.name == name }
            entries.insert(Entry(name: name, handicap: p.handicap), at: 0)
        }
        entries = Array(entries.prefix(Self.limit))
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }

    func forget(_ entry: Entry) {
        entries.removeAll { $0 == entry }
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }
}
