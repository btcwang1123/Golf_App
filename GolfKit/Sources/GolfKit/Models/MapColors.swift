import Foundation

/// Low-poly map colors (0xRRGGBB) shared by iPhone and Watch. Slightly desaturated to sit with the app theme.
public enum MapColors {
    public static let fairway: UInt32 = 0x5FA65A
    public static let green: UInt32 = 0x86CF78
    public static let tee: UInt32 = 0x99C77A
    public static let rough: UInt32 = 0x3D7A45
    public static let bunker: UInt32 = 0xD9CBA0
    public static let water: UInt32 = 0x4E93C6
    public static let outOfBounds: UInt32 = 0xF3EFE4
    public static let shotLine: UInt32 = 0xE9D3A0
    public static let shotMarker: UInt32 = 0xD6B97C
    public static let player: UInt32 = 0x5AA9F0
    public static let pin: UInt32 = 0xDE5A4F
    public static let target: UInt32 = 0xF3EFE4

    public static func fill(for kind: Feature.Kind) -> UInt32 {
        switch kind {
        case .fairway: fairway
        case .green: green
        case .tee: tee
        case .rough: rough
        case .bunker: bunker
        case .water, .lateralWater: water
        case .outOfBounds: outOfBounds
        }
    }
}
