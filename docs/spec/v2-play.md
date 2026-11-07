# V2 球場上的功能（T36–T42）

追上 Golfshot / 18Birdies / Hole19 / Garmin 的核心打球功能。總覽見 [SPEC.md](../../SPEC.md)。

### T36: 任意點測距
- Status: done
- Depends on: T09, T10
- Goal: 在地圖上拖動目標點，即時看「我→目標」與「目標→果嶺」距離。
- Files: `GolfApp/Features/HoleMap/{TargetMarker,DistanceArcsOverlay,HoleMapView}.swift`, `GolfApp/Features/Round/RoundView.swift`
- Interfaces: `HoleMapView(..., target: Binding<GeoPoint?>)`
- Acceptance:
  - 點地圖放置目標，拖曳可移動；兩段連線各自標距離
  - 沒放目標時預設在球道中線、距玩家約一般開球距離（依 T44 一號木平均，無資料時 200 碼）
  - 可顯示 100/150/200 碼距離弧（依單位），設定可關
  - 長按仍保留 T09「補一桿」功能（目標用單擊）
- Notes: 距離計算放 GolfKit `Geo`，View 只顯示

### T37: 障礙物距離（layup/carry）
- Status: done
- Depends on: T03
- Goal: 列出本洞每個沙坑/水障礙「到前緣」與「飛越」距離。
- Files: `GolfKit/Sources/GolfKit/Geometry/HazardDistances.swift`, `GolfKit/Tests/GolfKitTests/HazardDistancesTests.swift`, `GolfApp/Features/Round/{HazardListView,RoundView}.swift`
- Interfaces: `HazardDistances.compute(from: GeoPoint, hole: Hole, maxLateralMeters: Double = 40) -> [HazardDistance]`（`kind, front: Double, carry: Double, side: .left|.center|.right`）
- Acceptance:
  - 只列「在玩家到果嶺方向前方」且偏離打擊線 ≤ 40m 的障礙
  - front/carry ＝ 沿打擊方向與多邊形的近/遠交點；依 front 排序
  - 已在身後（front < 0）的障礙不列出
  - 回合畫面可展開清單；地圖上點障礙也顯示兩個距離
- Notes: 結果透過 Watch 本機計算（T46），不經同步

### T38: 旗桿位置
- Status: done
- Depends on: T04, T10, T15
- Goal: 使用者把旗桿拖到今天的位置，距離改以旗桿計算。
- Files: `GolfKit/Sources/GolfKit/Scoring/{RoundEvent,RoundState,RoundReducer}.swift`, `GolfKit/Tests/GolfKitTests/PinTests.swift`, `GolfApp/Features/HoleMap/PinMarker.swift`, `GolfApp/Features/Round/DistanceBadgeView.swift`, `GolfWatch/Features/Round/WatchHoleView.swift`
- Interfaces: `RoundEvent.Kind.setPin(hole: Int, location: GeoPoint)`；`RoundState.pin(for hole: Int) -> GeoPoint?`
- Acceptance:
  - 拖曳旗桿只能放在果嶺多邊形內（外面時吸回邊界）
  - 設定後到旗桿距離取代「中」，前/後仍以果嶺邊緣計算
  - 同步到 Watch，Watch 大字改顯示到旗桿
  - 快捷：果嶺上「前/中/後」三個預設位置一點即設
  - 該洞最後一桿距離（T04）改算到旗桿

### T39: 球洞飛越動畫
- Status: done (manual pending)
- Depends on: T09
- Goal: 進入每洞時，鏡頭從 tee 沿球道飛到果嶺，顯示洞資訊。
- Files: `GolfApp/Features/HoleMap/{HoleFlyover,HoleIntroOverlay,HoleCamera}.swift`, `GolfApp/Features/Round/RoundView.swift`
- Interfaces: `HoleFlyover.keyframes(for: Hole) -> [MapCamera]`（tee 後上方 → 落點 → 果嶺俯視 → 回到全洞）；`HoleIntroOverlay(hole:, lengthMeters:)`
- Acceptance:
  - 約 4 秒，用 `mapCameraKeyframeAnimator`；點一下可跳過
  - 疊加洞號、par、長度、handicap（淡入淡出）
  - 有 `.realistic` 高程的地區開啟地形；overlay 不貼地時退回 `.flat`
  - 設定可關閉「自動播放飛越」；有手動重播按鈕
  - 無 tee 或 greenCenter 的洞不播放
- Manual: 實機確認台灣地區 `.realistic` 是否有地形與 overlay 對齊狀況，結果寫在本任務 Notes
- Notes: 目前 `MapStyleConfig.useRealisticElevation = false`（一律 `.flat`）；實機確認 overlay 貼地後再改為 true。

### T40: 天氣與風向
- Status: done (manual pending)
- Depends on: T10
- Goal: 顯示目前風向風速（相對本洞方向）與溫度。
- Files: `GolfApp/Services/WeatherService.swift`, `GolfKit/Sources/GolfKit/Caddie/WindComponent.swift`, `GolfKit/Tests/GolfKitTests/WindComponentTests.swift`, `GolfApp/Features/Round/WindBadgeView.swift`, `project.yml`
- Interfaces: `WeatherService.current(at: GeoPoint) async -> WeatherSnapshot?`（15 分鐘快取）；`WindComponent.relative(windFromDeg:, speed:, holeBearing:) -> (head: Double, cross: Double)`
- Acceptance:
  - 回合畫面角落：箭頭（相對 tee→果嶺方向旋轉）、風速、溫度
  - 文字提示：「逆風 4 m/s」「左往右側風」
  - 無網路或無授權時隱藏，不顯示錯誤
  - 顯示 Apple Weather 標示與法律連結
- Manual: Apple Developer 開啟 WeatherKit capability 與 App ID 設定；project.yml 加 entitlement

### T41: 選桿建議
- Status: done
- Depends on: T38, T44
- Goal: 依使用者自己的歷史球桿距離，建議打到旗桿/目標用哪支桿。
- Files: `GolfKit/Sources/GolfKit/Caddie/ClubAdvisor.swift`, `GolfKit/Tests/GolfKitTests/ClubAdvisorTests.swift`, `GolfApp/Features/Round/ClubSuggestionView.swift`
- Interfaces: `ClubAdvisor.suggest(distance: Double, profile: ClubProfile, headwind: Double?) -> Suggestion?`（`club, expected: Double, alternative: Club?`）；`ClubProfile`（各桿中位數距離，來自 T44）
- Acceptance:
  - 選擇中位數距離最接近且 ≥ 目標距離 95% 的桿
  - 逆風每 1 m/s 視為距離 +1%（順風 −0.5%），可關閉
  - 某桿資料 < 3 筆時不採用；全部不足時顯示「記錄球桿以啟用建議」
  - 回合畫面距離旁顯示「建議 7 鐵（145 碼）」
- Notes: 不自動辨識球桿；靠使用者在 T10 點選某桿設定球桿的資料

### T42: Live Activity / 動態島
- Status: done (manual pending)
- Depends on: T07, T38
- Goal: 鎖定畫面與動態島顯示洞號、桿數、到果嶺距離，不用解鎖手機。
- Files: `GolfWidgets/{GolfWidgetsBundle,RoundLiveActivity}.swift`, `GolfKit/Sources/GolfKit/Sync/RoundActivityAttributes.swift`, `GolfApp/Services/LiveActivityService.swift`, `project.yml`
- Interfaces: `RoundActivityAttributes { courseName }`、`ContentState { hole, par, strokes, toPar, distanceToPin: Double? }`；`LiveActivityService.start/update/end`
- Acceptance:
  - 開始回合啟動、結束回合關閉；換洞、記桿時更新
  - 距離每移動 ≥ 5m 才更新，且每分鐘最多 4 次
  - 動態島 compact：洞號 + 距離；expanded：桿數、對標準桿差
  - 使用者關閉 Live Activities 時不報錯
- Manual: project.yml 新增 widget extension target 與 `NSSupportsLiveActivities`；Xcode 設定 signing
