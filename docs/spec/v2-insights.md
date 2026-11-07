# V2 統計分析（T43–T45）

讓人「越打越想看數據」，對標 Arccos / 18Birdies 的分析，但不需要感應器。總覽見 [SPEC.md](../../SPEC.md)。

### T43: 進階統計與趨勢
- Status: done
- Depends on: T16, T31
- Goal: 用 Swift Charts 呈現成績趨勢與桿數結構。
- Files: `GolfKit/Sources/GolfKit/Insights/{InsightsSummary,ScoringBreakdown}.swift`, `GolfKit/Tests/GolfKitTests/InsightsTests.swift`, `GolfApp/Features/Insights/{InsightsView,TrendChart,ScoringDistributionChart,ParTypeCard}.swift`
- Interfaces: `InsightsSummary.make(rounds: [RoundState], courses: [String: Course], lastN: Int?) -> InsightsSummary`（平均桿、最佳成績、平均對標準桿差、FIR%、GIR%、推桿/洞、罰桿/場、par3/4/5 平均、成績分布 eagle/birdie/par/bogey/double+ 比例）
- Acceptance:
  - 篩選：最近 5 / 10 / 20 場、全部；可只看某球場
  - 圖：對標準桿差折線（含移動平均）、成績分布長條、推桿數趨勢、FIR/GIR 趨勢
  - 9 洞回合以 9 洞統計，不與 18 洞混算平均桿
  - 手動輸入回合（無逐桿）只計入桿數類統計
  - 回合 < 3 場時顯示鼓勵空狀態
- Notes: 統計 tab 由 T34 新增

### T44: 球桿距離與落點散佈
- Status: done
- Depends on: T04, T43
- Goal: 每支桿的距離分布與左右偏差。
- Files: `GolfKit/Sources/GolfKit/Insights/{ClubProfile,DispersionStats}.swift`, `GolfKit/Tests/GolfKitTests/DispersionStatsTests.swift`, `GolfApp/Features/Insights/{ClubDistancesView,DispersionChart}.swift`
- Interfaces: `ClubProfile.build(rounds:, courses:) -> ClubProfile`（每桿 `count, median, p25, p75, longest`）；`DispersionStats.lateral(shot:, next:, target: GeoPoint) -> Double`（相對「擊球點→果嶺中心」線的左右偏差，右正左負）
- Acceptance:
  - 排除推桿、罰桿後的那一桿、距離 < 10m 或 > 350m 的異常值
  - 每桿顯示中位數與 p25–p75 區間條
  - 散佈圖：以擊球方向為上，畫各桿落點相對位置
  - `ClubProfile` 提供給 T36、T41 使用

### T45: Strokes Gained（估算）
- Status: done
- Depends on: T44, T20
- Goal: 把每桿表現換算成「比基準多/少幾桿」，分成開球、攻果嶺、短桿、推桿。
- Files: `GolfKit/Sources/GolfKit/Insights/{Lie,LieClassifier,BaselineTable,StrokesGained}.swift`, `GolfKit/Tests/GolfKitTests/StrokesGainedTests.swift`, `GolfApp/Features/Insights/StrokesGainedView.swift`
- Interfaces: `Lie: .tee|.fairway|.rough|.sand|.green|.recovery`；`LieClassifier.classify(_ p: GeoPoint, hole: Hole) -> Lie`（依 feature 多邊形，未覆蓋時 `.rough`）；`BaselineTable.expected(distance:, lie:) -> Double`（自訂近似表，線性內插）；`StrokesGained.compute(state:, course:) -> SGBreakdown`
- Acceptance:
  - 每桿 SG = expected(前) − expected(後) − 1；罰桿額外 −1
  - 分類：par4/5 的第 1 桿＝開球；距果嶺 > 30m＝攻果嶺；≤ 30m 非果嶺＝短桿；果嶺上＝推桿
  - 推桿距離缺定位時用「推桿數 vs 期望值」估算
  - 只對 `CourseQuality.level == .full` 的洞計算；其餘洞排除並提示
  - UI 明示「估算值，以業餘 15 差點為基準」
- Notes: 基準表自行建立（以公開常識為依據的平滑曲線），放常數檔方便調整
