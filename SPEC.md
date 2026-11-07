# GolfApp Spec

## Overview
iPhone + Apple Watch 高爾夫記桿 app，給台灣球友使用，**不用註冊、下載即用**。內建全台球場（OpenStreetMap）與「精選球場」完整 18 洞圖資，以 2.5D 斜視 low poly 色塊與飛越動畫呈現每一洞。
主流程：選球場 → 開始回合（可加同組朋友）→ Watch 偵測揮桿自動 +1 → 每桿記 GPS、算距離、到旗桿/障礙物距離、選桿建議 → 推桿手動 +1 → 下一洞 → 結算、分享成績卡、進階統計。
V2 目標：在球場推廣時，30 秒內讓人「想下載」——資料完整、展示模式、好看的分享卡、同組多人記分。

## Tech
- Xcode 16+、Swift 6（strict concurrency）、SwiftUI、XcodeGen（`project.yml`），不手改 `.pbxproj`
- Targets：iOS 17.0+（`GolfApp`）、watchOS 10.0+（`GolfWatch`）；V2 新增 `GolfWidgets`（iOS Live Activity）、`GolfWatchWidgets`（watchOS complication）
- Apple 框架：SwiftData、MapKit、CoreLocation、CoreMotion、HealthKit、WatchConnectivity；V2 加 Swift Charts、WidgetKit/ActivityKit、WeatherKit、CoreImage（QR）
- 無第三方套件；地圖資料 OpenStreetMap（ODbL，須顯示「© OpenStreetMap contributors」）；WeatherKit 須顯示 Apple Weather 標示
- 測試：Swift Testing，邏輯集中在 `GolfKit`：`swift test --package-path GolfKit`
- 產生專案：`xcodegen generate`；建置：`xcodebuild -scheme GolfApp -destination 'generic/platform=iOS Simulator' build`

## Architecture
- `GolfKit`（純 Foundation）：模型、幾何、計分、揮桿偵測、同步協定、V2 的多人/比賽/統計/選桿/資料品質。所有可測邏輯放這裡
- `osm-import` / `course-audit`（GolfKit executable targets）：開發期產生與檢查球場資料
- `GolfApp`（iOS）：球場、2.5D 地圖、回合、編輯器、歷史統計、分享、引導、展示模式、設定；`GolfApp/DesignSystem/`（`Theme`、`Components`）為唯一樣式來源
- `GolfWatch`（watchOS）：回合、揮桿偵測、Workout/定位、障礙物與小地圖頁
- 回合採 **event sourcing**：只產生 `RoundEvent`（UUID），`RoundState` 由事件重算，同步以 id 合併
- 依賴注入：`@Observable` service 經 `.environment(...)`；不用 singleton。定位以 `LocationProviding` protocol 注入（展示模式可換成模擬來源）
- 資料流：UI → `RoundStore.append(event)` → 持久化 + `SyncService.send` → 對端 `merge`

```
GolfKit/Sources/GolfKit/{Models,Geometry,Scoring,Swing,Sync,Players,Games,Insights,Quality,Caddie,Notes,Practice,Schedule,Import}/
GolfKit/Sources/{osm-import,course-audit}/
GolfApp/  App/ DesignSystem/ Features/{Courses,Round,HoleMap,Editor,History,Insights,Share,Group,Onboarding,Showcase,Home,Settings,Bets,Achievements,Recap,Plan,TeeTime,Manual}/ Intents/ Services/ Persistence/ Resources/
GolfWatch/ App/ Features/{Round,Settings,Practice}/ Intents/ Services/
GolfWidgets/  GolfWatchWidgets/
docs/spec/   任務細節
```

## Conventions
- 型別 UpperCamelCase，一檔一主要型別；View 以 `View` 結尾，service 以 `Service` 結尾
- GolfKit 型別皆 `Sendable`、`Codable`、`Equatable`；座標用 `GeoPoint`
- `@Observable` + async/await；不用 Combine、`ObservableObject`
- 距離內部一律公尺，顯示依設定（預設碼）
- UI 字串放 `Localizable.xcstrings`，繁中為主、V2 補英文
- 顏色、字級、圓角只能來自 `Theme`；View 內不寫 hex 色碼與 magic number
- 新邏輯先在 GolfKit 寫測試；View 不放商業邏輯、body 不做 I/O
- 新增 `RoundEvent.Kind` 必須向下相容：舊事件照常解碼，未知 kind 在 reducer 忽略而非 crash
- 避免：強制解包、Watch 載入整份全台球場 JSON

## Data
- `GeoPoint`、`Polygon`、`Feature`、`Hole`、`Course`：見 [v1-core](docs/spec/v1-core.md) 與 `GolfKit/Sources/GolfKit/Models/`
- `Course.source`：`.osm | .user | .featured`（V2：精選球場，打包在 `GolfApp/Resources/featured/*.json`，優先序 user > featured > osm）；`Course.provenance` 記錄資料來源，只有 osm/survey/licensed 可打包
- `RoundEvent.Kind` V2 新增：`addPlayer(Player)`、`playerScore(playerId, hole, strokes, putts?)`、`setPin(hole, GeoPoint)`、`setGame(GameFormat)`
- V3 新增：`penalty` 加選填 `reason: PenaltyReason`、`setBets(BetConfig)`、`wolfPick(hole, partnerId?)`；`SyncMessage.practice(PracticeSession)`
- `Player { id: UUID, name, handicap: Int?, isOwner }`；`GameFormat { .stroke | .stableford | .match | .skins, useHandicap }`
- `CourseQuality.Level`：`.full | .partial | .scoreOnly`（每洞判定，球場取整體）
- 檔案交換：`.golfcourse`（`Course` JSON）、`.golfround`（`RoundExport { events, players, courseId, courseName }`）
- 持久化：SwiftData `RoundRecord`、`UserCourseRecord`；V3 加 `HolePlanRecord`（每球場每洞攻略/筆記）、`RoundPhotoRecord`、`PracticeRecord`；開球時間存 UserDefaults；Widget 快照存 App Group；Watch 事件存 JSON 檔

## Out of scope
- 帳號登入、雲端同步、即時線上好友、發文/好友牆/社團/聊天（朋友間以檔案與圖片分享）
- 官方 WHS 差點（缺 course/slope rating），只做「平均對標準桿差」趨勢
- 球桿感應器硬體、自動辨識球桿與推桿、AR、真實高程「實際打距」
- 從 Apple/Google 衛星圖描繪後**打包散布**（Apple 地圖條款）；精選球場資料只來自 OSM（以 OSM 允許的影像描繪）、實地踩點或球場授權；例外：國土測繪中心正射影像（政府資料開放授權條款）自動辨識的球道／沙坑／水塘（`Tools/README.md` autotrace → `aerial_tw.json`）
- Android、iPad 專屬版面、旗桿位置雲端共享（球場合作另議）

## Tasks

細節依區塊放在 `docs/spec/`。建議推廣優先順序：T20→T21→T22→T25 → T35 → T29 → T26→T27 → T31→T32→T33。

| ID | 標題 | 狀態 | 細節 |
|---|---|---|---|
| T01–T19 | V1 核心：骨架、模型、幾何、計分、OSM 匯入、球場、回合、地圖、編輯器、揮桿偵測、Watch、同步、歷史、校正、設定、自動換洞 | done | [v1-core](docs/spec/v1-core.md) |
| T20 | 球場資料品質檢查 | done | [v2-data](docs/spec/v2-data.md) |
| T21 | 精選球場資料層 | done | [v2-data](docs/spec/v2-data.md) |
| T22 | 實地踩點模式 | done (manual pending) | [v2-data](docs/spec/v2-data.md) |
| T23 | 編輯器 v2（快速描繪） | done | [v2-data](docs/spec/v2-data.md) |
| T24 | 球場資料包匯入/匯出 | done (manual pending) | [v2-data](docs/spec/v2-data.md) |
| T25 | 推廣球場圖資製作 | done (manual pending) | [v2-data](docs/spec/v2-data.md) |
| T26 | 多人同組模型 | done | [v2-social](docs/spec/v2-social.md) |
| T27 | 多人記分 UI | done | [v2-social](docs/spec/v2-social.md) |
| T28 | 比賽模式 | done | [v2-social](docs/spec/v2-social.md) |
| T29 | 分享成績卡圖片 | done | [v2-social](docs/spec/v2-social.md) |
| T30 | 回合檔分享給同組 | done | [v2-social](docs/spec/v2-social.md) |
| T31 | 視覺系統統一與動效 | done | [v2-polish](docs/spec/v2-polish.md) |
| T32 | App Icon、啟動畫面、品牌 | done (manual pending) | [v2-polish](docs/spec/v2-polish.md) |
| T33 | 新手引導與權限 | done | [v2-polish](docs/spec/v2-polish.md) |
| T34 | 首頁改版 | done | [v2-polish](docs/spec/v2-polish.md) |
| T35 | 展示模式（推廣用） | done | [v2-polish](docs/spec/v2-polish.md) |
| T36 | 任意點測距 | done | [v2-play](docs/spec/v2-play.md) |
| T37 | 障礙物距離（layup/carry） | done | [v2-play](docs/spec/v2-play.md) |
| T38 | 旗桿位置 | done | [v2-play](docs/spec/v2-play.md) |
| T39 | 球洞飛越動畫 | done (manual pending) | [v2-play](docs/spec/v2-play.md) |
| T40 | 天氣與風向 | done (manual pending) | [v2-play](docs/spec/v2-play.md) |
| T41 | 選桿建議 | done | [v2-play](docs/spec/v2-play.md) |
| T42 | Live Activity / 動態島 | done (manual pending) | [v2-play](docs/spec/v2-play.md) |
| T43 | 進階統計與趨勢 | done | [v2-insights](docs/spec/v2-insights.md) |
| T44 | 球桿距離與落點散佈 | done | [v2-insights](docs/spec/v2-insights.md) |
| T45 | Strokes Gained（估算） | done | [v2-insights](docs/spec/v2-insights.md) |
| T46 | Watch 障礙物/旗桿頁 | done | [v2-watch](docs/spec/v2-watch.md) |
| T47 | Watch complication | done (manual pending) | [v2-watch](docs/spec/v2-watch.md) |
| T48 | Watch 球洞小地圖 | done | [v2-watch](docs/spec/v2-watch.md) |
| T49 | 英文在地化與無障礙 | done | [v2-polish](docs/spec/v2-polish.md) |
| T50 | 效能、電量與穩定性 | done (manual pending) | [v2-polish](docs/spec/v2-polish.md) |
| T51 | App Store 上架準備 | done (manual pending) | [v2-polish](docs/spec/v2-polish.md) |
| T52 | 罰桿原因 | done | [v3-features](docs/spec/v3-features.md) |
| T53 | 賭局記帳與結算 | done | [v3-features](docs/spec/v3-features.md) |
| T54 | 成就與里程碑 | done | [v3-features](docs/spec/v3-features.md) |
| T55 | 月度／年度回顧 | done | [v3-features](docs/spec/v3-features.md) |
| T56 | 短桿與推桿細項統計 | done | [v3-features](docs/spec/v3-features.md) |
| T57 | 揮桿節奏 | done | [v3-features](docs/spec/v3-features.md) |
| T58 | Watch 練習場模式 | done | [v3-features](docs/spec/v3-features.md) |
| T59 | 打球速度計時 | done | [v3-features](docs/spec/v3-features.md) |
| T60 | 攻略規劃、每洞筆記與照片 | done | [v3-features](docs/spec/v3-features.md) |
| T61 | 紙本記分卡掃描 | done | [v3-features](docs/spec/v3-features.md) |
| T62 | Siri／捷徑 App Intents | done | [v3-features](docs/spec/v3-features.md) |
| T63 | Watch 雙指互點 | done | [v3-features](docs/spec/v3-features.md) |
| T64 | 主畫面 Widget | done (manual pending) | [v3-features](docs/spec/v3-features.md) |
| T65 | 開球時間提醒與天氣預報 | done (manual pending) | [v3-features](docs/spec/v3-features.md) |
