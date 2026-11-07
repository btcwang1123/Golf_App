# V2 Apple Watch（T46–T48）

Watch 揮桿自動記桿是本 app 相對 Golfshot / Garmin 最大的差異點；這一區補齊 Garmin 手錶級的距離資訊。總覽見 [SPEC.md](../../SPEC.md)。

### T46: Watch 障礙物/旗桿頁
- Status: done
- Depends on: T37, T38, T14
- Goal: 錶上滑到第二頁看障礙物與 layup 距離，旗桿位置跟手機同步。
- Files: `GolfWatch/Features/Round/{WatchHazardPageView,WatchRoundView}.swift`, `GolfWatch/Features/Round/WatchHoleView.swift`
- Acceptance:
  - 回合用 vertical `TabView`：主頁 / 障礙物 / 小地圖（T48）/ 記分卡
  - 障礙物頁：每列圖示 + 前緣 / 飛越距離，錶冠捲動；依 T37 本機計算
  - 每 3 秒或移動 ≥ 3m 更新一次
  - 設了旗桿後主頁大字標「旗」；可在錶上選前/中/後三個預設位置
- Notes: 不在 Watch 上渲染 MapKit

### T47: Watch complication
- Status: done (manual pending)
- Depends on: T14
- Goal: 錶面顯示回合中的洞號與到果嶺距離，點一下回到 app。
- Files: `GolfWatchWidgets/{GolfWatchWidgetsBundle,RoundComplication}.swift`, `GolfWatch/Services/ComplicationService.swift`, `project.yml`
- Interfaces: 透過 App Group 共享 `ComplicationSnapshot { hole, strokes, distanceToPin, updatedAt }`
- Acceptance:
  - 支援 circular、rectangular、inline；Smart Stack 回合中優先顯示
  - 無回合時顯示 app 圖示與「開始」
  - 更新次數符合 WidgetKit 預算（記桿、換洞時 `reloadTimelines`）
- Manual: project.yml 新增 watchOS widget extension 與 App Group；Xcode signing

### T48: Watch 球洞小地圖
- Status: done
- Depends on: T14, T38
- Goal: 錶上畫出本洞色塊與自己的位置，點一下量距離。
- Files: `GolfKit/Sources/GolfKit/Geometry/HoleProjection.swift`, `GolfKit/Tests/GolfKitTests/HoleProjectionTests.swift`, `GolfWatch/Features/Round/WatchHoleMapView.swift`
- Interfaces: `HoleProjection(hole:, size: CGSize)`：以 tee→果嶺方向朝上旋轉、等比縮放的 `project(GeoPoint) -> CGPoint` / `unproject`
- Acceptance:
  - SwiftUI `Canvas` 畫 fairway、green、bunker、water、玩家點、旗桿
  - 點螢幕位置 → 顯示「我→該點」與「該點→旗桿」距離
  - 錶冠縮放（1x–3x）
  - 無圖資的洞顯示「此洞無圖資」
- Notes: 顏色沿用 `MapPalette`（GolfKit 中放色碼常數供兩端共用）
