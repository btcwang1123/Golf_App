# V3 對標其他 App 的功能（T52–T65）

對照 Arccos、18Birdies、Golfshot、Garmin Golf、Hole19，補上不需帳號與雲端就能做的功能。全部邏輯放在 GolfKit 並有測試（`GolfKit/Tests/GolfKitTests/V3FeatureTests.swift`）。總覽見 [SPEC.md](../../SPEC.md)。

### T52: 罰桿原因
- Status: done
- Files: `GolfKit/Sources/GolfKit/Scoring/{PenaltyReason,RoundEvent,RoundReducer,RoundState}.swift`, `GolfApp/Features/Round/StrokeControlsView.swift`
- Interfaces: `RoundEvent.Kind.penalty(hole:count:reason: PenaltyReason? = nil)`；`PenaltyReason { outOfBounds, water, lostBall, unplayable, other }`；`HoleState.penaltyReasons`
- Acceptance: 舊的 `penalty` 事件（無 reason）照常解碼；未知 reason 解碼為 nil 不失敗；罰桿選單可選原因

### T53: 賭局記帳與結算
- Status: done
- Files: `GolfKit/Sources/GolfKit/Games/{BetConfig,BetSettlement}.swift`, `GolfApp/Features/Bets/{BetSetupView,SettlementView}.swift`, `GolfApp/Features/Group/{AddPlayersView,LeaderboardView}.swift`
- Interfaces: `RoundEvent.Kind.setBets(BetConfig)`、`.wolfPick(hole:partnerId: UUID?)`；`BetSettlement.compute(state:course:) -> BetSettlement { games, totals, transfers }`；`BetSettlement.minimalTransfers(_:)`
- 玩法：比桿差（兩兩每桿一注）、Nassau（前九/後九/全場）、Skins（平手累積）、博蒂獎金（博蒂 1 注、老鷹 2 注…）、拉斯維加斯（4 人兩隊、兩位數、博蒂反轉對手數字）、鬥地主（3–4 人輪流當地主，選隊友或單挑雙倍）
- Acceptance: 每個賭局淨額總和為 0；可選差點淨桿（以全組最低差點為基準）；結算以最少筆數轉帳呈現；可分享文字結算；回合中可在排行榜變更賭局
- Notes: App 只記帳，不處理任何金流

### T54: 成就與里程碑
- Status: done
- Files: `GolfKit/Sources/GolfKit/Insights/Achievement.swift`, `GolfApp/Features/Achievements/AchievementsView.swift`, `GolfApp/Features/Round/RoundSummaryView.swift`
- Interfaces: `Achievement`（21 項，含 tier/symbol）；`AchievementEngine.earned(by:)`、`unlocks(rounds:)`、`newlyUnlocked(in:rounds:)`
- Acceptance: 破百/90/80 與零三推、零罰桿只計 18 洞回合；一桿進洞限 Par 3；連續 Par/博蒂需洞號相連；結算頁顯示「本場解鎖」

### T55: 月度／年度回顧
- Status: done
- Files: `GolfKit/Sources/GolfKit/Insights/PeriodRecap.swift`, `GolfApp/Features/Recap/RecapView.swift`, `GolfApp/Features/Home/HomeView.swift`
- Interfaces: `PeriodRecap.make(period:rounds:unlocks:calendar:)`、`availablePeriods(rounds:)`
- Acceptance: 場數、洞數、最佳 18/9 洞、博蒂/老鷹/Par、最常去球場、愛用球桿、最遠一桿、步行距離、前後半段進步；可輸出 9:16 圖片分享

### T56: 短桿與推桿細項統計
- Status: done
- Files: `GolfKit/Sources/GolfKit/Insights/ShortGameStats.swift`, `GolfApp/Features/Insights/ShortGameView.swift`
- Acceptance: Up & Down（未 GIR 仍 Par 以下）、果嶺旁沙坑救球（60 m 內、兩桿內進洞）、一推/三推、第一推距離分段進洞率（需推桿 GPS）、罰桿來源

### T57: 揮桿節奏（Tempo）
- Status: done
- Files: `GolfKit/Sources/GolfKit/Swing/TempoStats.swift`, `GolfApp/Features/Insights/TempoPracticeView.swift`, `GolfWatch/Features/Round/SwingToastView.swift`
- Acceptance: 理想 2.6–3.4:1；過濾 0.8–8 以外雜訊；依球桿分組；Watch 揮桿提示顯示節奏

### T58: 練習場模式（Watch）
- Status: done
- Files: `GolfKit/Sources/GolfKit/Practice/PracticeSession.swift`, `GolfWatch/Features/Practice/{WatchPracticeStore,WatchPracticeView}.swift`, `GolfApp/Services/PracticeStore.swift`, `GolfApp/Persistence/HolePlanRecord.swift`
- Interfaces: `SyncMessage.practice(PracticeSession)`；`SwingMonitor.onPracticeSwing`
- Acceptance: 無回合時可開始；每次揮桿計數並震動；可選球桿、刪除上一桿；結束後傳到 iPhone 存 `PracticeRecord`；進行中當機可從檔案恢復

### T59: 打球速度計時
- Status: done
- Files: `GolfKit/Sources/GolfKit/Scoring/PaceOfPlay.swift`, `GolfApp/Features/Round/PaceBadgeView.swift`, `GolfWatch/Features/Round/WatchScorecardPageView.swift`
- Acceptance: 每洞時間 = 本洞第一桿到下一洞第一桿；以 14 分/洞為基準顯示快/慢（±5 分內為正常）；結算與詳情顯示總時間、每洞平均、最久一洞

### T60: 攻略規劃與每洞筆記、照片
- Status: done
- Files: `GolfKit/Sources/GolfKit/Notes/HolePlan.swift`, `GolfApp/Features/Plan/*`, `GolfApp/Services/HolePlanStore.swift`, `GolfApp/Persistence/HolePlanRecord.swift`
- Interfaces: `HolePlan { courseId, hole, targets, clubs, note }`；`HolePlan.teeShotMiss(_:)`、`adherence(plans:round:)`；SwiftData `HolePlanRecord`、`RoundPhotoRecord`
- Acceptance: 球場頁「攻略規劃」在地圖點最多 3 個目標點並選桿；回合中依桿數把下一個目標點當預設瞄準點；開球前顯示筆記；回合中可寫筆記、拍照；詳情顯示開球平均偏離目標

### T61: 紙本記分卡掃描
- Status: done
- Files: `GolfKit/Sources/GolfKit/Import/ScorecardParser.swift`, `GolfApp/Features/Manual/{ScorecardScanView,ManualRoundEntryView}.swift`
- Acceptance: Vision 本機辨識；找出洞號列（1–9 / 10–18，可缺 2 格）、PAR 列、略過 HCP/碼數列；前後九依列序合併；選列後預填手動記分
- Notes: 無標籤的 PAR 列只接受 3–5 且多數為 4，避免把成績誤判為 PAR

### T62: Siri／捷徑 App Intents
- Status: done
- Files: `GolfApp/Intents/{IntentBridge,RoundIntents}.swift`, `GolfWatch/Intents/WatchIntents.swift`
- Acceptance: iPhone：記一桿、記推桿、記罰桿（可選原因）、這洞 N 桿、下一洞、目前成績（含到果嶺距離）；Watch：記一桿、記推桿，可由捷徑指定給 Ultra 動作按鈕

### T63: Watch 雙指互點
- Status: done
- Files: `GolfWatch/Features/Round/WatchHoleView.swift`
- Acceptance: watchOS 11+ Double Tap 觸發主按鈕（果嶺上為推桿 +1，否則手動 +1）；watchOS 10 不受影響

### T64: 主畫面／鎖定畫面 Widget
- Status: done (manual pending)
- Files: `GolfKit/Sources/GolfKit/Sync/HomeWidgetSnapshot.swift`, `GolfWidgets/HomeStatsWidget.swift`, `GolfApp/Services/WidgetSnapshotService.swift`
- Acceptance: small/medium/accessoryRectangular/accessoryCircular；最近一場、走勢、成就數、下次開球；App 於資料變動時寫入 App Group 並重新整理
- Manual: 真機確認 App Group 已在開發者帳號啟用（GolfWidgets 新增 entitlements）

### T65: 開球時間提醒與天氣預報
- Status: done (manual pending)
- Files: `GolfKit/Sources/GolfKit/Schedule/TeeTime.swift`, `GolfApp/Services/TeeTimeStore.swift`, `GolfApp/Features/TeeTime/TeeTimeViews.swift`, `GolfApp/Services/WeatherService.swift`
- Acceptance: 前一晚 20:00 提醒（10 天內附 WeatherKit 逐時預報）、開球前 N 分鐘出發提醒；首頁顯示下次開球與預報；過期超過 7 天自動清除
- Manual: 真機確認通知與 WeatherKit 預報
