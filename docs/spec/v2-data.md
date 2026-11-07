# V2 球場資料（T20–T25）

目前 122 座球場中只有 14 座有洞資料、約 5 座有果嶺多邊形。這是推廣時最大的弱點：找不到自己的球場就會刪 app。總覽見 [SPEC.md](../../SPEC.md)。

### T20: 球場資料品質檢查
- Status: done
- Depends on: T02, T05
- Goal: 以統一規則判定每洞/每座球場的圖資完整度，供 UI 標籤、編輯器清單與 CLI 報表使用。
- Files: `GolfKit/Sources/GolfKit/Quality/{CourseQuality,HoleQuality}.swift`, `GolfKit/Sources/course-audit/main.swift`, `GolfKit/Package.swift`, `GolfKit/Tests/GolfKitTests/CourseQualityTests.swift`, `GolfApp/Features/Courses/CourseRowView.swift`
- Interfaces: `HoleQuality.evaluate(_ hole: Hole) -> HoleQuality`（`missing: Set<Item>`，Item：`tee, greenCenter, greenPolygon, par, fairway, hazards, handicap`）；`CourseQuality.evaluate(_ c: Course) -> CourseQuality`（`level: Level`、`holes: [HoleQuality]`、`score: Double 0...1`）；CLI `swift run --package-path GolfKit course-audit GolfApp/Resources/courses_tw.json [--featured GolfApp/Resources/featured]`
- Acceptance:
  - `.full`：每洞有 tee、greenCenter、greenPolygon、par（fairway/hazards 加分但非必要）
  - `.partial`：至少一半的洞有 tee + greenCenter；其餘為 `.scoreOnly`
  - CLI 依完整度排序輸出表格（名稱、洞數、level、缺漏數），最後一行為統計
  - 球場列表標籤改用 level：「完整圖資 / 部分圖資 / 僅記桿」
- Notes: 規則寫在 `CourseQuality` 常數，不散落在 View

### T21: 精選球場資料層
- Status: done
- Depends on: T06, T20
- Goal: 打包經人工驗證的完整球場，優先於 OSM 版本顯示。
- Files: `GolfKit/Sources/GolfKit/Models/Course.swift`, `GolfApp/Services/CourseRepository.swift`, `GolfApp/Resources/featured/README.md`, `GolfApp/Features/Courses/{CourseListView,CourseRowView}.swift`, `project.yml`
- Interfaces: `Course.Source.featured`；`Course.provenance: .osm|.survey|.licensed|.userTraced?`（T22/T25 用來判斷能否打包）；`Course.replaces: String?`（覆蓋的 OSM id）；`CourseRepository` 合併順序 user > featured > osm
- Acceptance:
  - `featured/*.json` 每檔一座 `Course`，啟動時背景載入
  - featured 球場以 `replaces` 隱藏對應 OSM 球場，搜尋不重複
  - 列表中精選球場有「精選」徽章並排在同距離的前面
  - 舊版 `source` 只有 osm/user 的 JSON 仍可解碼
- Notes: README 說明資料來源規則（OSM、實地踩點、球場授權），不收錄從 Apple/Google 衛星圖描繪的資料

### T22: 實地踩點模式
- Status: done (manual pending)
- Depends on: T06, T11
- Goal: 人站在球場上，用 GPS 平均值標記 tee、果嶺與果嶺邊界，產生可合法散布的自有資料。
- Files: `GolfKit/Sources/GolfKit/Geometry/PointAverager.swift`, `GolfKit/Tests/GolfKitTests/PointAveragerTests.swift`, `GolfApp/Features/Editor/{SurveyModeView,SurveyModel}.swift`, `GolfApp/Features/Editor/CourseEditorView.swift`
- Interfaces: `PointAverager { mutating func add(_ p: GeoPoint, accuracy: Double); var result: GeoPoint?; var spreadMeters: Double }`（丟棄 accuracy > 10m 的樣本）；`SurveyModel`（目前洞、動作：標記 tee / 果嶺前 / 中 / 後 / 開始繞果嶺 / 結束繞果嶺）
- Acceptance:
  - 標記點：取樣 8 秒，顯示精度與倒數，完成後寫入目前洞
  - 繞果嶺：記錄行走軌跡，結束時閉合並以 1m 簡化成 green 多邊形
  - 精度不足（平均 > 8m）時警告並允許重測
  - 標記完 tee + 果嶺中心即自動產生 path，存成 user 球場，`Course.provenance = .survey`
- Manual: 實機到球場驗證
- Notes: 先標 tee 再走到果嶺，一洞約 2 分鐘；可邊打球邊踩

### T23: 編輯器 v2（快速描繪）
- Status: done
- Depends on: T11, T20
- Goal: 讓描繪一洞從數分鐘降到 1 分鐘內。
- Files: `GolfApp/Features/Editor/{HoleEditorView,PolygonDrawingView,EditorModel,EditorChecklistView,MagnifierView}.swift`
- Interfaces: `EditorModel.moveVertex(polygon:, index:, to:)`、`insertVertex`、`copyFeatures(fromHole:)`、`checklist: [HoleQuality.Item: Bool]`
- Acceptance:
  - 頂點可拖曳；點兩頂點中間插入新點；拖曳時顯示放大鏡
  - 新點距既有頂點 < 2m 自動吸附
  - 每洞顯示 T20 缺漏清單，點項目直接切到對應工具
  - 「下一個缺資料的洞」按鈕
  - 完成度百分比顯示於球場編輯頁
- Notes: 描繪仍只存本機（user 球場）；散布請走 T25 的 OSM 流程

### T24: 球場資料包匯入/匯出
- Status: done (manual pending)
- Depends on: T21
- Goal: 以 `.golfcourse` 檔分享球場（AirDrop / LINE / 檔案 app）。
- Files: `GolfKit/Sources/GolfKit/Models/CoursePackage.swift`, `GolfKit/Tests/GolfKitTests/CoursePackageTests.swift`, `GolfApp/Features/Courses/{CourseImportView,CourseExportButton}.swift`, `GolfApp/App/GolfApp.swift`, `project.yml`
- Interfaces: `CoursePackage { version: Int, course: Course, exportedAt: Date }`；`CoursePackage.encode() -> Data`、`decode(_:) throws`
- Acceptance:
  - 球場詳情頁「分享球場資料」產生 `<名稱>.golfcourse`
  - 開啟檔案 → 預覽（名稱、洞數、完整度、地圖縮圖）→ 匯入為 user 球場；同 id 時詢問覆蓋
  - 版本不符或損毀時顯示錯誤，不 crash
- Manual: project.yml 宣告 exported UTType `com.<you>.golfapp.course`（副檔名 golfcourse）與 document type；確認 bundle id

### T25: 推廣球場圖資製作
- Status: done (manual pending)
- Depends on: T20, T21, T22
- Goal: 把要推廣的球場做到 18 洞完整圖資並打包進 app。
- Files: `GolfApp/Resources/featured/*.json`, `GolfApp/Resources/courses_tw.json`, `Tools/README.md`
- Acceptance:
  - 目標球場 `course-audit` 結果皆為 `.full`
  - 每座精選球場實機開一場回合，抽查 3 洞的果嶺中心距離誤差 < 5m
- Manual:
  - 列出推廣球場清單（先 3–5 座）
  - 路線 A（建議）：在 openstreetmap.org 用 iD 編輯器、以 OSM 允許的影像（Esri / Bing）描 `golf=hole/green/tee/fairway/bunker/water_hazard`，填 `ref`、`par`、`handicap`；之後重跑 `osm-import`（`--input` 不用快取）
  - 路線 B：到現場用 T22 踩點，匯出 `.golfcourse` 後轉存到 `featured/`
  - 路線 C：取得球場提供的球道圖授權
- Notes: 這是人工作業，程式無法替代；也同時回饋 OSM 社群

## 先後順序
T20 → T21 → T22/T23（可平行）→ T24 → T25
