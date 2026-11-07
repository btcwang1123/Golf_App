import Foundation

public struct GameFormat: Sendable, Codable, Equatable, Hashable {
    public enum Kind: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
        case stroke, stableford, match, skins

        public var title: String {
            switch self {
            case .stroke: "比桿"
            case .stableford: "Stableford"
            case .match: "比洞"
            case .skins: "Skins"
            }
        }

        /// Match play is head-to-head only.
        public func allows(playerCount: Int) -> Bool {
            self == .match ? playerCount == 2 : playerCount >= 1
        }
    }

    public var kind: Kind
    public var useHandicap: Bool

    public init(kind: Kind = .stroke, useHandicap: Bool = false) {
        self.kind = kind
        self.useHandicap = useHandicap
    }

    public static let stroke = GameFormat()
}
