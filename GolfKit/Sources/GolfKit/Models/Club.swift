import Foundation

public enum Club: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case driver, w3, w5, h4, i4, i5, i6, i7, i8, i9, pw, gw, sw, lw, putter

    public var displayName: String {
        switch self {
        case .driver: "1W"
        case .w3: "3W"
        case .w5: "5W"
        case .h4: "4H"
        case .i4: "4I"
        case .i5: "5I"
        case .i6: "6I"
        case .i7: "7I"
        case .i8: "8I"
        case .i9: "9I"
        case .pw: "PW"
        case .gw: "GW"
        case .sw: "SW"
        case .lw: "LW"
        case .putter: "推桿"
        }
    }
}
