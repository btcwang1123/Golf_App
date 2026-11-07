# V2 同組與分享（T26–T30）

高爾夫通常四人一組：一人用 app 幫大家記分，其他三人就會看到；打完的成績卡圖片會被傳到群組。這是不靠廣告擴散的主要管道。全部不需帳號。總覽見 [SPEC.md](../../SPEC.md)。

### T26: 多人同組模型
- Status: done
- Depends on: T04
- Goal: 回合事件支援同組朋友的成績（朋友以手動整洞輸入，擁有者照舊逐桿記錄）。
- Files: `GolfKit/Sources/GolfKit/Players/{Player,PlayerScore}.swift`, `GolfKit/Sources/GolfKit/Scoring/{RoundEvent,RoundState,RoundReducer}.swift`, `GolfKit/Tests/GolfKitTests/MultiPlayerTests.swift`
- Interfaces: `Player { id: UUID, name: String, handicap: Int?, isOwner: Bool }`；`RoundEvent.Kind.addPlayer(Player)`、`.removePlayer(UUID)`、`.playerScore(playerId: UUID, hole: Int, strokes: Int, putts: Int?)`；`RoundState.players: [Player]`、`RoundState.scores(for playerId: UUID) -> [Int: PlayerScore]`、`total(for:)`、`toPar(for:)`；擁有者分數仍由 `holes` 導出
- Acceptance:
  - 無 `addPlayer` 的舊回合 → `players` 只含擁有者，其餘行為不變
  - 同一 player 同一洞多次 `playerScore` → 取 timestamp 最新
  - `removePlayer` 後該員分數不再出現
  - reducer 遇到未知 kind（解碼成 `.unknown`）忽略不 crash
  - 合併/冪等測試同 T04
- Notes: 最多 4 人（擁有者 + 3）；Watch 端只顯示擁有者，但要能解碼並轉發新事件

### T27: 多人記分 UI
- Status: done
- Depends on: T26, T10
- Goal: 開局加朋友，每洞結束快速輸入大家的桿數，隨時看排行。
- Files: `GolfApp/Features/Group/{AddPlayersView,PlayerScoreEntrySheet,LeaderboardView,RecentPlayersStore}.swift`, `GolfApp/Features/Round/{RoundView,ScorecardSheet}.swift`, `GolfApp/Features/Courses/CourseDetailView.swift`
- Interfaces: `RecentPlayersStore`（UserDefaults 存最近 10 位名字與差點）
- Acceptance:
  - 開始回合前可加 0–3 位朋友（從最近名單一點即加）
  - 擁有者進入下一洞時跳出輸入面板：每人一列，預設 par，左右 ± 調整，一鍵確認；可跳過
  - 記分卡顯示所有人，依 T31 色彩標示 birdie/bogey
  - 排行榜：總桿、對標準桿差、名次，回合中可隨時開啟
- Notes: 輸入面板要能單手 3 秒內完成 4 人

### T28: 比賽模式
- Status: done
- Depends on: T26
- Goal: 支援常見玩法：比桿、Stableford、比洞、Skins，可套差點讓桿。
- Files: `GolfKit/Sources/GolfKit/Games/{GameFormat,GameScorer,HandicapAllocator}.swift`, `GolfKit/Tests/GolfKitTests/GameScorerTests.swift`, `GolfApp/Features/Group/{GameSetupView,LeaderboardView}.swift`
- Interfaces: `GameFormat { kind: .stroke|.stableford|.match|.skins; useHandicap: Bool }`；`RoundEvent.Kind.setGame(GameFormat)`；`HandicapAllocator.strokes(handicap:, holeHandicap:, holeCount:) -> Int`；`GameScorer.standings(state: RoundState, course: Course?) -> [Standing]`（`playerId, points/net, rank, detail`）
- Acceptance:
  - Stableford：淨桿 vs par，雙柏忌以上 0、柏忌 1、平標 2、博蒂 3、老鷹 4
  - 比洞：兩人時逐洞勝負、顯示「2 UP / 3&2」；超過兩人時不可選
  - Skins：該洞唯一最低者拿 1 skin，平手累積到下一洞
  - 差點讓桿依洞 handicap 分配；無洞 handicap 時按洞號平均分配並在 UI 提示
- Notes: 單機記錄，不涉金錢；UI 不出現賭注字樣

### T29: 分享成績卡圖片
- Status: done
- Depends on: T16, T31
- Goal: 打完一鍵產生好看、會想分享的成績卡圖片。
- Files: `GolfApp/Features/Share/{ScorecardShareView,ShareCardTemplate,ShareCardRenderer,QRCodeGenerator}.swift`, `GolfApp/Features/History/RoundDetailView.swift`
- Interfaces: `ShareCardTemplate`：`.story`（1080×1920）、`.square`（1080×1080）、`.scorecard`（18 洞表）；`ShareCardRenderer.render(_ template:, round: RoundState, course: Course?, players: [Player]) -> UIImage`（`ImageRenderer`，scale 3）
- Acceptance:
  - 內容：球場名、日期、總桿與對標準桿差（大字）、前/後九、亮點（博蒂數、最遠一桿、最少推桿洞）、精選洞的 low poly 縮圖、多人時顯示排行
  - 角落小字 app 名稱 + QR code（App Store 連結，未上架前用設定中的網址）
  - 結算頁與歷史詳情頁皆有「分享」：`ShareLink` 開分享面板（LINE、IG、相簿）
  - 圖片在淺色/深色背景上都清楚；文字不超出邊界（最長球場名測試）
- Notes: IG 限動直接貼圖需 Facebook App ID，本版走系統分享面板即可

### T30: 回合檔分享給同組
- Status: done
- Depends on: T26, T24
- Goal: 同組朋友收到 `.golfround` 後可把這場存進自己的歷史。
- Files: `GolfKit/Sources/GolfKit/Sync/RoundExport.swift`, `GolfKit/Tests/GolfKitTests/RoundExportTests.swift`, `GolfApp/Features/Share/{RoundImportView,RoundExportButton}.swift`, `GolfApp/App/GolfApp.swift`, `project.yml`
- Interfaces: `RoundExport { version, events: [RoundEvent], players: [Player], courseId, courseName, viewerPlayerId: UUID? }`
- Acceptance:
  - 匯入時選「我是哪一位」，以該員視角存成新回合（分數為整洞成績，無逐桿軌跡）
  - 同一檔重複匯入不產生重複回合（以 roundId + viewer 判斷）
  - 本機沒有該球場時仍可匯入，以 `courseName` 顯示
- Manual: project.yml 宣告 UTType `com.<you>.golfapp.round`（副檔名 golfround）
- Notes: 對方沒有 app 時，檔案無法開啟 → 分享時同時附 T29 的圖片（含 QR 下載連結）
