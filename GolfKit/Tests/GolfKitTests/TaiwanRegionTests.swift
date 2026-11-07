import Testing
@testable import GolfKit

struct TaiwanRegionTests {
    @Test func majorCities() {
        #expect(TaiwanRegion.of(GeoPoint(lat: 25.03, lon: 121.56)) == .north)   // 台北
        #expect(TaiwanRegion.of(GeoPoint(lat: 25.13, lon: 121.74)) == .north)   // 基隆
        #expect(TaiwanRegion.of(GeoPoint(lat: 24.99, lon: 121.30)) == .north)   // 桃園
        #expect(TaiwanRegion.of(GeoPoint(lat: 24.80, lon: 120.97)) == .north)   // 新竹
        #expect(TaiwanRegion.of(GeoPoint(lat: 24.15, lon: 120.67)) == .central) // 台中
        #expect(TaiwanRegion.of(GeoPoint(lat: 23.91, lon: 120.68)) == .central) // 南投
        #expect(TaiwanRegion.of(GeoPoint(lat: 23.48, lon: 120.45)) == .south)   // 嘉義
        #expect(TaiwanRegion.of(GeoPoint(lat: 22.63, lon: 120.30)) == .south)   // 高雄
        #expect(TaiwanRegion.of(GeoPoint(lat: 22.00, lon: 120.75)) == .south)   // 恆春
        #expect(TaiwanRegion.of(GeoPoint(lat: 24.75, lon: 121.75)) == .east)    // 宜蘭
        #expect(TaiwanRegion.of(GeoPoint(lat: 23.97, lon: 121.60)) == .east)    // 花蓮
        #expect(TaiwanRegion.of(GeoPoint(lat: 22.75, lon: 121.14)) == .east)    // 台東
        #expect(TaiwanRegion.of(GeoPoint(lat: 23.57, lon: 119.58)) == .islands) // 澎湖
        #expect(TaiwanRegion.of(GeoPoint(lat: 24.43, lon: 118.32)) == .islands) // 金門
    }
}
