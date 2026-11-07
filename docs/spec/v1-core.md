# V1 核心（T01–T19）

已完成的第一版任務細節。總覽與索引見 [SPEC.md](../../SPEC.md)。


### T01: 專案骨架與 GolfKit 套件
- Status: done
- Depends on: —
- Goal: 建立可建置的 iOS + watchOS 專案與 GolfKit 本地套件。
- Files: `project.yml`, `GolfKit/Package.swift`, `GolfKit/Sources/GolfKit/GolfKit.swift`, `GolfKit/Tests/GolfKitTests/SmokeTests.swift`, `GolfApp/App/GolfApp.swift`, `GolfApp/App/RootView.swift`, `GolfWatch/App/GolfWatchApp.swift`, `GolfWatch/App/WatchRootView.swift`, `.gitignore`
- Interfaces: Package products `GolfKit`(library), `osm-import`(executable)；platforms `.iOS(.v17), .watchOS(.v10), .macOS(.v14)`
- Acceptance:
  - `swift test --package-path GolfKit` 通過
  - `xcodegen generate` 後 `GolfApp` scheme 對 iOS Simulator 建置成功，Watch app 嵌入
  - 兩個 target 都 link GolfKit
- Manual: `brew install xcodegen`；在 Xcode 設定 Signing Team；確認 bundle id（`com.<you>.golfapp` / `.watchkitapp`）
- Notes: Info.plist key 由 project.yml 產生：`NSLocationWhenInUseUsageDescription`、`NSMotionUsageDescription`、`NSHealthShareUsageDescription`、`NSHealthUpdateUsageDescription`；Watch `WKBackgroundModes: [workout-processing]`；Watch 加 HealthKit entitlement

### T02: 核心模型與 JSON 編解碼
- Status: done
- Impl note: JSON fixtures live in `GolfKit/Tests/GolfKitTests/Fixtures/Data/` (SwiftPM resource dir).
- Depends on: T01
- Goal: 定義 Data 章節的球場模型並可從 JSON 讀寫。
- Files: `GolfKit/Sources/GolfKit/Models/{GeoPoint,Feature,Hole,Course,Club}.swift`, `GolfKit/Tests/GolfKitTests/CourseCodingTests.swift`, `GolfKit/Tests/GolfKitTests/Fixtures/sample_course.json`
- Interfaces: `Course.decodeList(from: Data) throws -> [Course]`；`enum Club: String, Codable, CaseIterable`（driver, w3, w5, h4, i4…i9, pw, gw, sw, lw, putter）
- Acceptance:
  - 範例 fixture（1 球場 2 洞）decode → encode → decode 結果相等
  - 缺 `par`/`green` 的洞可正常解碼
- Notes: JSON 座標精度存 6 位小數以縮小檔案

### T03: 幾何工具
- Status: done
- Impl note: `greenFrontCenterBack` returns a `GreenDistances` struct instead of a tuple; also `greenDistancesMeters(from:)`.
- Depends on: T02
- Goal: 提供距離、方位、多邊形與簡化運算。
- Files: `GolfKit/Sources/GolfKit/Geometry/{Geo,PolygonOps,Simplify}.swift`, `GolfKit/Tests/GolfKitTests/GeometryTests.swift`
- Interfaces: `Geo.distance(_:_:) -> Double`（haversine，公尺）、`Geo.bearing(_:_:) -> Double`（度）、`Geo.midpoint`、`PolygonOps.contains(_ p: GeoPoint, in: Polygon) -> Bool`、`PolygonOps.centroid`、`PolygonOps.distance(from: GeoPoint, toPolyline:) -> Double`、`Simplify.douglasPeucker(_:epsilonMeters:) -> [GeoPoint]`、`Hole.greenFrontCenterBack(from: GeoPoint) -> (front, center, back)?`
- Acceptance:
  - 已知兩點距離誤差 < 0.5%
  - 凹多邊形 contains 正確；簡化後頭尾點保留且點數減少
  - 果嶺前/中/後：沿「目前位置→果嶺中心」射線與果嶺多邊形的近/遠交點；無多邊形時以中心 ±12m 估算

### T04: 計分引擎（event sourcing）
- Status: done
- Impl note: acceptance "揮桿 3 + void 1" interpreted as 4 swings with 1 voided (3 live) + 2 putts + 1 penalty = 6. GIR counts penalties before first putt.
- Depends on: T02, T03
- Goal: 由 `RoundEvent` 序列導出完整回合狀態與統計。
- Files: `GolfKit/Sources/GolfKit/Scoring/{RoundEvent,RoundState,RoundReducer,RoundStats}.swift`, `GolfKit/Tests/GolfKitTests/RoundReducerTests.swift`
- Interfaces: `RoundReducer.reduce(_ events: [RoundEvent], course: Course?) -> RoundState`；`RoundState.holes: [HoleState]`（strokes, putts, penalties, total, shots: [ShotInfo(distanceToNext: Double?)]）；`RoundState.currentHole`、`totalStrokes`、`toPar`；`RoundStats`（FIR, GIR, putts/hole, avg distance by club）；`merge(_ a: [RoundEvent], _ b: [RoundEvent]) -> [RoundEvent]`（依 id 去重、依 timestamp 排序）
- Acceptance:
  - 揮桿 3 + void 1 + penalty 1 + 推桿 2 → 該洞 6 桿
  - 每桿距離＝與下一個有位置的 stroke 的距離；該洞最後一桿（非推桿）距離＝到果嶺中心
  - 合併重複事件結果不變（冪等）、順序不同結果相同
  - GIR：上果嶺時桿數 ≤ par−2（以第一個 putt 前桿數判定）；FIR 只對 par ≥4，以第 1 桿落點（第 2 桿位置）是否在 fairway 多邊形內
- Notes: `void` 指向不存在 id 時忽略；無 par 時 toPar 不計該洞

### T05: OSM 匯入工具
- Status: done
- Impl note: generated 2026-11-05: 122 courses, 14 with hole data, 269 holes. Raw Overpass cache at `build/osm/` (gitignored).
- Depends on: T03
- Goal: 一次性腳本抓取全台球場並輸出打包用 JSON。
- Files: `GolfKit/Sources/osm-import/main.swift`, `GolfKit/Sources/GolfKit/Import/{OverpassModels,OSMCourseBuilder}.swift`, `GolfKit/Tests/GolfKitTests/OSMCourseBuilderTests.swift`, `GolfKit/Tests/GolfKitTests/Fixtures/overpass_sample.json`, `Tools/README.md`
- Interfaces: CLI `swift run --package-path GolfKit osm-import --out GolfApp/Resources/courses_tw.json [--input cached.json]`；`OSMCourseBuilder.build(from: OverpassResponse) -> [Course]`
- Acceptance:
  - Overpass query：台灣 bbox（21.8,119.3,25.4,122.1）內 `leisure=golf_course` 及其範圍內 `golf=hole|tee|fairway|green|bunker|water_hazard|lateral_water_hazard|rough|pin`、`natural=water`，`out geom`
  - `golf=hole` 線段 → `Hole`（`ref`→number、`par`、`handicap`，首點 tee、末點附近果嶺）
  - 未連結的 feature 依「centroid 到洞路徑最近且 < 60m」分配到洞，否則放 course-level
  - 多邊形以 1.5m 簡化；fixture 測試產出洞數、par 正確
  - 輸出統計：球場數、有洞資料的球場數（寫到 stdout）
- Manual: 開發者在終端機執行一次並 commit 產出的 JSON
- Notes: 名稱優先 `name:zh`→`name`；縣市用 `addr:city` 或之後用中心點反查（可先留空）；尊重 Overpass 使用量（單次查詢、加 `--input` 快取）

### T06: 球場資料庫（iOS）
- Status: done
- Depends on: T02, T05
- Goal: 載入內建 + 使用者球場並提供搜尋、附近查詢。
- Files: `GolfApp/Services/CourseRepository.swift`, `GolfApp/Persistence/UserCourseRecord.swift`, `GolfApp/Services/LocationService.swift`
- Interfaces: `@Observable final class CourseRepository { func all() -> [Course]; func search(_ q: String) -> [Course]; func nearby(_ p: GeoPoint, limit: Int) -> [Course]; func course(id:) -> Course?; func save(userCourse: Course) }`；`LocationService`（when-in-use，`current: GeoPoint?`、`accuracy`）
- Acceptance:
  - 使用者版本以相同 id 覆蓋內建版
  - 搜尋不分大小寫、支援部分中文字
  - 載入於背景 task，不阻塞主執行緒

### T07: 回合持久化與 RoundStore
- Status: done
- Depends on: T04
- Goal: iPhone 端儲存回合事件並對 UI 暴露即時狀態。
- Files: `GolfApp/Persistence/{RoundRecord,ModelContainer+App}.swift`, `GolfApp/Services/RoundStore.swift`
- Interfaces: `@Observable final class RoundStore { var active: RoundState?; func start(course:); func append(_ kind: RoundEvent.Kind); func merge(_ events: [RoundEvent]); func end(); func history() -> [RoundRecord] }`
- Acceptance:
  - App 被終止重開後，進行中回合可恢復
  - `append` 後 `active` 立即更新；事件以 JSON 存在 `eventsData`
  - 同一時間最多一個進行中回合

### T08: 球場列表與選擇 UI
- Status: done
- Depends on: T06, T07
- Goal: 首頁可看附近球場、搜尋並開始回合。
- Files: `GolfApp/Features/Courses/{CourseListView,CourseRowView,CourseDetailView}.swift`, `GolfApp/App/RootView.swift`
- Acceptance:
  - 有定位時依距離排序並顯示公里數；無權限時依名稱排序
  - 球場顯示「有球洞圖 / 僅記桿」標籤
  - 詳情頁可「開始回合」、「編輯球場」；有進行中回合時首頁顯示「繼續回合」
  - 頁尾顯示 OSM 版權
- Notes: Tab 架構：球場 / 歷史 / 設定

### T09: 2.5D low poly 球洞地圖
- Status: done
- Depends on: T03, T06
- Goal: 以 MapKit 斜視呈現單洞的平面色塊、tee、果嶺與標記。
- Files: `GolfApp/Features/HoleMap/{HoleMapView,HoleCamera,MapPalette,FeatureOverlay}.swift`
- Interfaces: `HoleMapView(course:, hole:, shots: [ShotInfo], player: GeoPoint?, onLongPress: (GeoPoint) -> Void)`；`HoleCamera.camera(for: Hole) -> MapCamera`（中心＝tee/green 中點、heading＝tee→green 方位、pitch 55°、distance≈洞長×2.2）
- Acceptance:
  - Feature 依 kind 用 `MapPalette` 平面色＋細描邊畫成 `MapPolygon`（繪製順序 rough→fairway→water→bunker→tee→green）
  - 底圖可切換：淡化標準圖（隱藏 POI）/ 衛星圖
  - 顯示玩家位置、每桿標記與桿間連線，線上標距離
  - 長按地圖回傳座標（給手動補桿/量距離用）
  - 無洞資料時顯示球場中心衛星圖與「此洞無圖資，可前往編輯」
- Notes: 色盤 fairway `#6BBF59`、green `#8FE07A`、tee `#A3D977`、rough `#3E8E41`、bunker `#E8D8A0`、water `#4FA3E0`、OB 白線。`elevation: .realistic` 下 overlay 是否貼地需實機驗證，預設用 `.flat`

### T10: iPhone 回合畫面
- Status: done
- Depends on: T07, T09
- Goal: 回合中顯示地圖、桿數、距離並可手動操作。
- Files: `GolfApp/Features/Round/{RoundView,HoleHeaderView,DistanceBadgeView,StrokeControlsView,ScorecardSheet}.swift`
- Acceptance:
  - 顯示洞號、par、本洞桿數、總桿/對標準桿差
  - 即時到果嶺前/中/後距離（依目前定位）
  - 按鈕：+1 揮桿（記錄目前位置）、+1 推桿、+1 罰桿、復原上一桿；長按地圖可在該點補一桿
  - 左右滑或按鈕切換洞；無 par 時可在 header 設定 par
  - Scorecard sheet 顯示 18 洞表格
  - 點選某桿可設定球桿或刪除

### T11: 球場編輯器
- Status: done
- Depends on: T06, T09
- Goal: 在 Apple 衛星圖上自行描繪缺資料的球洞。
- Files: `GolfApp/Features/Editor/{CourseEditorView,HoleEditorView,PolygonDrawingView,EditorModel}.swift`
- Interfaces: `EditorModel`（目前洞、工具：tee/綠中心/果嶺/球道/沙坑/水/OB、`undo()`）
- Acceptance:
  - 可新增球場（名稱、洞數 9/18）或從 OSM 球場複製後編輯
  - 每洞可點選 tee、果嶺中心、設定 par；可逐點描繪多邊形、閉合、刪除
  - 存檔後 `CourseRepository` 以 `user-`/原 id 覆蓋，地圖立即使用新資料
  - 描好 tee 與果嶺中心即可產生 `path` 與相機
- Notes: 使用者描繪資料只存本機、不上傳

### T12: 揮桿偵測演算法
- Status: done
- Depends on: T02
- Goal: 純邏輯的串流揮桿偵測器，可用合成資料測試。
- Files: `GolfKit/Sources/GolfKit/Swing/{MotionSample,SwingDetector,SwingDetectorConfig,SwingMetrics}.swift`, `GolfKit/Tests/GolfKitTests/SwingDetectorTests.swift`, `GolfKit/Tests/GolfKitTests/Fixtures/SyntheticSwings.swift`
- Interfaces: `struct MotionSample { t: TimeInterval; rotationRate: SIMD3<Double>; userAccel: SIMD3<Double> }`；`final class SwingDetector { init(config:); func ingest(_ s: MotionSample) -> SwingEvent? }`；`SwingEvent { t, metrics: SwingMetrics(peakRotation, peakAccel, tempo) }`；`SwingDetectorConfig { peakRotation=12 rad/s, backswingMinRotation=3 rad/s, backswingWindow=0.4...2.5s, impactAccel=2.5 g, impactWindow=±0.12s, refractory=4s, sensitivity 0.5...1.5 }`
- Acceptance:
  - 合成全揮桿（上桿→下桿峰值→撞擊尖峰）偵測 1 次
  - 走路、揮手、拿桿甩一下（無上桿段）不觸發
  - 連續兩次揮桿間隔 < refractory 只算 1 次
  - sensitivity 調高門檻按比例降低
  - 100Hz 每筆 ingest 為 O(1)（環形緩衝）
- Notes: 練習揮桿無法可靠分辨 → 交給 UI「取消」。門檻值需 T17 實測校正；推桿不偵測

### T13: Watch 動作/Workout/定位服務
- Status: done
- Impl note: built & compiled only; sensor/workout behaviour unverified until real-device test.
- Depends on: T12
- Goal: 回合中在背景持續取樣並發出揮桿事件（含位置）。
- Files: `GolfWatch/Services/{WorkoutService,MotionService,WatchLocationService,SwingMonitor}.swift`
- Interfaces: `WorkoutService.start()/end()`（`HKWorkoutSession` activityType `.golf`、location `.outdoor`）；`MotionService` 以 `CMMotionManager.deviceMotion` 100Hz 推 `MotionSample`；`SwingMonitor`（`@Observable`，`var lastSwing: SwingEvent?`，將事件附上最近 ≤5s 且精度 ≤20m 的位置）
- Acceptance:
  - 開始回合即啟動 workout，螢幕熄滅時仍持續偵測（實機驗證）
  - 結束回合停止取樣、workout 存入健康 App
  - 未授權 HealthKit/定位時顯示說明並仍可手動記桿
- Manual: 需實體 Apple Watch 驗證（模擬器無感測器）
- Notes: 設定中的配戴手（左/右）以 X 軸鏡像處理

### T14: Watch 回合 UI
- Status: done
- Depends on: T04, T13
- Goal: 手錶上完成整場記桿的主要互動。
- Files: `GolfWatch/Features/Round/{WatchRoundView,SwingToastView,WatchHoleView,WatchRoundStore}.swift`
- Interfaces: `WatchRoundStore`（同 RoundStore 介面，事件存本機 JSON 檔）
- Acceptance:
  - 主畫面：洞號、par、本洞桿數、總桿、到果嶺中心距離（大字）、前/後（小字）
  - 偵測到揮桿：震動（`.success`）+ 自動 +1，顯示 5 秒 toast：「取消」（送 `void`）、「+1 罰桿」（送 `penalty`）；逾時自動收起
  - 按鈕：推桿 +1、手動 +1、下一洞/上一洞；數位錶冠可調本洞桿數
  - 在果嶺多邊形內時「推桿 +1」按鈕放大置頂
  - 無手機連線時可獨立進行整場
- Notes: 5 秒視窗長度放設定；Watch 只收到當前球場的 `Course`（由 T15 傳入）

### T15: iPhone ↔ Watch 同步
- Status: done
- Impl note: `.course`/`.startRound` and the round-start `.events` go through `transferUserInfo` (FIFO) to keep ordering; Watch also joins a round from an incoming `.start` event.
- Depends on: T07, T14
- Goal: 回合事件與球場資料在兩端可靠同步。
- Files: `GolfKit/Sources/GolfKit/Sync/SyncMessage.swift`, `GolfApp/Services/PhoneSyncService.swift`, `GolfWatch/Services/WatchSyncService.swift`, `GolfKit/Tests/GolfKitTests/SyncMessageTests.swift`
- Interfaces: `enum SyncMessage: Codable { case events([RoundEvent]); case course(Course); case startRound(roundId, courseId); case settings(AppSettings) }`
- Acceptance:
  - 可達時 `sendMessage`，不可達時 `transferUserInfo` 排隊，重連後補送
  - 手機開始回合 → Watch 自動進入回合畫面；Watch 開始回合 → 手機出現該回合
  - 兩端重複收到同事件不重複計桿（依 T04 merge）
  - 回合結束後兩端總桿一致

### T16: 回合結算與歷史
- Status: done
- Depends on: T07, T09
- Goal: 回顧每場成績、每洞擊球軌跡與統計。
- Files: `GolfApp/Features/History/{HistoryListView,RoundDetailView,HoleReplayView,StatsView}.swift`
- Acceptance:
  - 列表：日期、球場、總桿、對標準桿差
  - 詳情：記分卡、推桿數、罰桿、FIR%、GIR%
  - 點洞可在 HoleMapView 看每桿位置與距離
  - 統計頁：最近 N 場平均桿數、各球桿平均距離（有標註球桿的桿）
  - 可刪除回合（需確認）

### T17: 揮桿資料錄製/校正模式
- Status: done
- Depends on: T13
- Goal: 錄下真實揮桿感測資料以校正 T12 門檻。
- Files: `GolfWatch/Features/Settings/CalibrationView.swift`, `GolfWatch/Services/MotionRecorder.swift`, `GolfApp/Features/Settings/CalibrationExportView.swift`
- Acceptance:
  - Watch 上「開始錄製」→ 以 CSV（t,rx,ry,rz,ax,ay,az）存檔，並標記使用者按下的「真揮桿/練習揮桿/走路」標籤
  - 透過 `transferFile` 傳到手機，可用分享面板匯出
  - 錄製中即時顯示偵測器是否觸發，方便比對
- Manual: 到練習場實錄數十次揮桿，把 CSV 放進 `GolfKit/Tests/GolfKitTests/Fixtures/` 作回歸測試

### T18: 設定
- Status: done
- Depends on: T15
- Goal: 使用者偏好並同步到 Watch。
- Files: `GolfKit/Sources/GolfKit/Models/AppSettings.swift`, `GolfApp/Features/Settings/SettingsView.swift`, `GolfWatch/Features/Settings/WatchSettingsView.swift`
- Interfaces: `AppSettings { distanceUnit: .yard|.meter (預設 .yard); wrist: .left|.right; swingSensitivity: Double; undoWindowSeconds: Int (5); autoAdvanceHole: Bool; hapticsOn: Bool }`
- Acceptance:
  - 修改後兩端即時生效；距離顯示全 app 依單位轉換
  - 設定頁含 OSM 版權與資料說明

### T19: 自動換洞
- Status: done
- Depends on: T04, T14
- Goal: 離開果嶺走向下一洞 tee 時自動切換洞。
- Files: `GolfKit/Sources/GolfKit/Scoring/HoleAdvanceDetector.swift`, `GolfKit/Tests/GolfKitTests/HoleAdvanceDetectorTests.swift`, `GolfWatch/Features/Round/WatchRoundStore.swift`
- Interfaces: `HoleAdvanceDetector.suggest(current: Int, location: GeoPoint, state: HoleState, course: Course) -> Int?`
- Acceptance:
  - 本洞有推桿且位置距下一洞 tee < 40m（且離本洞果嶺 > 30m）→ 建議下一洞
  - Watch 震動提示並自動切換，可一鍵退回
  - 設定關閉時不動作；無圖資球場不動作
