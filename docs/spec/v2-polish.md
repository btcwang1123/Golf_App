# V2 質感、第一印象與上架（T31–T35、T49–T51）

已有 `GolfApp/DesignSystem/{Theme,Components}.swift`（深綠 + 香檳金的會所風）。這一區負責把整個 app 統一到這套風格，並做出在球場推廣時 30 秒內能打動人的體驗。總覽見 [SPEC.md](../../SPEC.md)。

### T31: 視覺系統統一與動效
- Status: done
- Depends on: T08, T10, T16
- Goal: 所有畫面只用 `Theme`/`Components`，加上一致的過場、觸覺回饋與空狀態。
- Files: `GolfApp/DesignSystem/{Theme,Components,Motion,Haptics,EmptyStateView}.swift`, `GolfApp/Features/**/*View.swift`（逐一套用）, `GolfApp/Features/HoleMap/MapPalette.swift`
- Interfaces: `Motion.standard/.snappy/.hero`（`Animation`）；`Haptics.play(_ e: .stroke|.birdie|.holeChange|.warning)`；`EmptyStateView(icon:, title:, message:, action:)`
- Acceptance:
  - `grep -rn "Color(hex\|Color(red" GolfApp/Features` 無結果
  - 桿數變動數字有 `contentTransition(.numericText())`；換洞有方向性過場
  - 博蒂以上出現短暫慶祝動畫（金色光暈，0.8 秒，可在設定關閉）
  - 列表、歷史、統計空的時候顯示 `EmptyStateView`，不出現空白頁
  - 載入球場時顯示骨架（redacted placeholder）
  - `MapPalette` 色彩與 Theme 協調（地圖色塊稍降飽和）
- Notes: 先改 RoundView、CourseListView、RoundDetailView 三個最常見畫面

### T32: App Icon、啟動畫面、品牌
- Status: done (manual pending)
- Depends on: —
- Goal: 決定 app 名稱與圖示，讓 App Store 與主畫面第一眼就有質感。
- Files: `GolfApp/Resources/Assets.xcassets/{AppIcon.appiconset,LaunchBackground.colorset,LaunchLogo.imageset}`, `GolfWatch/Resources/Assets.xcassets/AppIcon.appiconset`, `project.yml`
- Acceptance:
  - iOS 1024 單一圖示（含深色、染色版本）、watchOS 圖示
  - 啟動畫面背景 = `Theme.background`，置中 logo，和首頁無縫接上
  - `CFBundleDisplayName` 設為最終名稱（中英文）
- Manual: 設計圖示（可外包或用設計工具）；決定 app 名稱；確認名稱在 App Store 未被使用

### T33: 新手引導與權限
- Status: done
- Depends on: T18, T31
- Goal: 首次開啟 3 頁說明價值，並在需要時才要權限。
- Files: `GolfApp/Features/Onboarding/{OnboardingView,OnboardingPage,PermissionPrimerView}.swift`, `GolfApp/App/RootView.swift`, `GolfApp/Services/SettingsService.swift`
- Acceptance:
  - 3 頁：「手錶揮桿自動記桿」「全台球場 2.5D 球道圖」「和朋友一起記分、分享成績」，每頁有動態示意（可重用 T35 素材）
  - 明確寫「不用註冊，下載就能用」
  - 最後一頁：選距離單位、配戴手、（可選）常去球場
  - 定位權限在第一次進球場列表前說明後再請求；動作與健康在第一次開始回合前說明
  - 拒絕權限時仍可手動記桿，設定頁可重新開啟
  - 可從設定頁重看引導；有「看展示」按鈕進 T35
- Notes: 引導完成旗標存在 `AppSettings`

### T34: 首頁改版
- Status: done
- Depends on: T20, T31
- Goal: 首頁一眼看到「今天在哪打、上次打得如何」。
- Files: `GolfApp/Features/Home/{HomeView,NearbyCourseHeroCard,LastRoundCard,QuickStatsRow}.swift`, `GolfApp/App/RootView.swift`
- Acceptance:
  - Tab 改為：首頁 / 球場 / 歷史 / 統計 / 設定
  - 首頁頂部：最近球場大卡（照片位置用 low poly 第 1 洞縮圖、距離、完整度標籤、「開始回合」）
  - 有進行中回合時改顯示「繼續第 N 洞」大卡
  - 上一場成績卡片（可點進詳情、可分享）與 3 個統計（平均桿、GIR%、平均推桿）
  - 無定位時顯示常去球場或搜尋入口

### T35: 展示模式（推廣用）
- Status: done
- Depends on: T21, T29, T39
- Goal: 不用下場，30–60 秒自動播放完整體驗，給推廣現場和新使用者看。
- Files: `GolfApp/Features/Showcase/{ShowcaseView,ShowcaseScript,SimulatedLocationProvider}.swift`, `GolfApp/Services/{LocationService,LocationProviding}.swift`, `GolfApp/Services/RoundStore.swift`, `GolfApp/Resources/showcase_round.json`
- Interfaces: `protocol LocationProviding { var current: GeoPoint? { get }; var accuracy: Double? { get } }`；`SimulatedLocationProvider(track: [GeoPoint], speed:)`；`ShowcaseScript`：時間軸步驟（飛越 → 走到落點 → 自動 +1 動畫 → 距離變化 → 果嶺推桿 → 結算 → 成績卡）
- Acceptance:
  - 從引導頁或設定頁「看展示」進入；在首頁標題長按 2 秒也可進入（現場用）
  - 使用一座精選球場的 2–3 洞，畫面與真實回合相同元件
  - 展示資料不寫入歷史、不影響進行中回合（獨立 `RoundStore` 實例，in-memory）
  - 可暫停、跳過、重播；結束頁有「開始我的第一場」
  - 播放流暢無卡頓（實機 60fps 目測）
- Notes: 這是推廣最重要的一頁，所有動畫在這裡要最精緻

### T49: 英文在地化與無障礙
- Status: done
- Depends on: T31
- Goal: 補英文介面並通過基本 VoiceOver/動態字級。
- Files: `GolfApp/Resources/Localizable.xcstrings`, `GolfWatch/Resources/Localizable.xcstrings`, `GolfApp/Features/**/*View.swift`
- Acceptance:
  - 所有字串有 en；系統語言英文時全英文顯示（球場名維持原文）
  - 主要按鈕、距離、桿數有 `accessibilityLabel`（例：「到果嶺中心 152 碼」）
  - 動態字級到 XXL 時回合畫面不重疊（可縮放主數字）
  - 色彩對比：主要文字 ≥ 4.5:1

### T50: 效能、電量與穩定性
- Status: done (manual pending)
- Depends on: T13, T31
- Goal: 一整場 18 洞不卡、不當、Watch 撐得完。
- Files: `GolfApp/Services/{DiagnosticsService,CourseRepository}.swift`, `GolfWatch/Services/{MotionService,WatchLocationService}.swift`, `GolfApp/Features/Settings/DiagnosticsView.swift`
- Acceptance:
  - 冷啟動到首頁可互動 < 1.5 秒（iPhone 12 等級）
  - MetricKit 收集 crash/hang 報告存本機，設定頁可匯出
  - Watch：螢幕熄滅時定位降頻（距離過濾 5m）；4.5 小時回合耗電 < 60%（實測）
  - 回合中 App 被系統終止，重開可恢復（同 T07）
- Manual: 實機打一場全程測電量並記錄結果到 `Tools/README.md`

### T51: App Store 上架準備
- Status: done (manual pending)
- Depends on: T32, T33, T49
- Goal: 備齊上架所需檔案與素材。
- Files: `GolfApp/Resources/PrivacyInfo.xcprivacy`, `GolfWatch/Resources/PrivacyInfo.xcprivacy`, `GolfAppUITests/ScreenshotTests.swift`, `project.yml`, `Tools/AppStore.md`
- Acceptance:
  - Privacy manifest 宣告使用的 API（UserDefaults 等）與「不收集資料」
  - UI 測試以展示資料自動截出 6.9"、6.1"、Watch 截圖
  - `Tools/AppStore.md`：名稱、副標、關鍵字、描述（繁中/英文）、隱私權政策文字、OSM 與 Apple Weather 標示
- Manual: Apple Developer 帳號、App Store Connect 建立 app、上傳截圖、TestFlight 給推廣前的種子使用者
