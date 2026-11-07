/// GolfKit: pure-Foundation domain logic shared by the iOS and watchOS apps.
public enum GolfKit {
    public static let version = "0.1.0"
    public static let osmAttribution = "© OpenStreetMap contributors"
    /// Source of the auto-traced fairways / bunkers / water (政府資料開放授權條款).
    public static let aerialAttribution = "航照 © 內政部國土測繪中心"
    /// Combined credit line for map screens.
    public static let mapAttribution = "\(osmAttribution) · \(aerialAttribution)"
}
