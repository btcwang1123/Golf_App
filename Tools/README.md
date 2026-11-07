# Tools

## osm-import

Builds the bundled course list `courses_tw.json` from OpenStreetMap (Overpass API).

```
swift run --package-path GolfKit osm-import --out GolfApp/Resources/courses_tw.json
# reuse a cached response (no network):
swift run --package-path GolfKit osm-import --out GolfApp/Resources/courses_tw.json \
    --input GolfApp/Resources/courses_tw.json.overpass-cache.json
```

- Without `--input` it sends one POST (Taiwan bbox 21.8,119.3,25.4,122.1) to `https://overpass-api.de/api/interpreter` and saves the raw response to `<out>.overpass-cache.json`. Please be considerate of the public Overpass servers: run it rarely and use `--input` while iterating. Do not commit the cache file (it is large).
- Prints: total courses, courses with hole data, total holes.
- Run once, then commit the generated JSON.

## Attribution (ODbL)

Data is (c) OpenStreetMap contributors, licensed under the ODbL (https://www.openstreetmap.org/copyright). The app must display "(c) OpenStreetMap contributors", and derived databases (the generated JSON) remain under ODbL.

## course-audit (T20)

Checks map-data completeness with the same rules the app uses (`CourseQuality`).

```
swift run --package-path GolfKit course-audit GolfApp/Resources/courses_tw.json [--featured GolfApp/Resources/featured] [--only-mapped]
```

Prints courses sorted by level (`full` → `partial` → `scoreOnly`) and score, with missing-item counts, then a summary line.
`--promote <osm-id> --out <file> [--id <featured-id>]` copies an OSM course into a featured JSON (`provenance: osm`, `replaces: <osm-id>`).

## 推廣球場圖資製作 (T25)

Promotion list (first 3–5 courses): fill in, then bring each to `full`.

| 球場 | 路線 | 狀態 |
|---|---|---|
| 臺灣高爾夫俱樂部球場 | A (OSM) | featured, full (16 holes in OSM — verify the remaining 2) |
| _待定_ | | |

- **Route A (recommended):** edit on openstreetmap.org with iD using OSM-permitted imagery (Esri / Bing):
  `golf=hole` (with `ref`, `par`, `handicap`), `golf=green/tee/fairway/bunker/water_hazard`.
  Then re-run `osm-import` without `--input` (fresh download) and `course-audit --promote`.
- **Route B:** on site with the app's survey mode (Course editor → 實地踩點模式), export `.golfcourse`, copy the `course` into `featured/`.
- **Route C:** licensed hole maps from the course.
- Acceptance: `course-audit` = `full`; play one round per featured course and spot-check 3 green-center distances (< 5 m error).

## Battery / performance log (T50)

Record a full 18-hole round on device here (target: watch < 60 % over 4.5 h; cold launch < 1.5 s on iPhone 12).

| 日期 | 裝置 | 時長 | 手錶耗電 | 冷啟動 | 備註 |
|---|---|---|---|---|---|
| | | | | | |

The in-app Settings → 診斷與效能 page shows launch timing and MetricKit reports.

## osm-buildings

Builds `GolfApp/Resources/buildings_tw.json` (course id → building footprints + heights) for the low-poly
"game" hole map, so players can orient themselves by nearby buildings. Only courses with hole data are queried
(bbox of the course + 350 m), in one Overpass POST.

```
swift run --package-path GolfKit osm-buildings --courses GolfApp/Resources/courses_tw.json \
    --featured GolfApp/Resources/featured --out GolfApp/Resources/buildings_tw.json
# reuse a cached response (no network):
    ... --input <buildings_tw.json.overpass-cache.json>
```

- Footprints are simplified to ≤ 10 vertices; height comes from `height`, else `building:levels` × 3.2 m, else a
  default per building type. Move the `.overpass-cache.json` out of `Resources/` (it would be bundled).
- Re-run after adding featured courses or re-running `osm-import`. Data is ODbL like the course data.

## autotrace（空照圖自動辨識球道／沙坑／水塘）

從內政部國土測繪中心正射影像（WMTS `PHOTO2`，政府資料開放授權條款）自動辨識球道、沙坑、水塘，
產生 `GolfApp/Resources/aerial_tw.json`（以球場 id 為 key 的 `[Feature]`，App 載入時併入 `courses_tw.json`）。
果嶺不自動辨識（準確度不足），由使用者在編輯器「果嶺中心」工具每洞點一下，系統依球道推算發球台／距離／PAR
（`GolfKit.HoleAutoLayout`）。

```
cd Tools/autotrace
uv venv .venv && uv pip install --python .venv/bin/python -r requirements.txt
C=../../build/osm/courses_tw.json.overpass-cache.json   # osm-import 產生的 Overpass 快取
J=../../GolfApp/Resources/courses_tw.json
# 1) 下載每座球場範圍的 z19 空照拼圖（約 0.27 m/px；有快取，可重跑）
.venv/bin/python fetch.py $C <osm數字id> ../../build/aerial/<osm數字id> 19
# 2) 用 OSM 已有圖資的球場訓練（兩階段 auto-context 像素分類）
.venv/bin/python train.py $J ../../build/aerial ../../build/aerial/model.pkl <id> <id> ...
# 3) 對全部球場辨識並輸出（某球場 OSM 已有該類圖形則跳過該類）
.venv/bin/python build_aerial.py ../../build/aerial/model.pkl $J ../../build/aerial ../../GolfApp/Resources/aerial_tw.json
# 單一球場檢查（輸出 overlay.jpg；最後兩個參數可與 OSM 比對準確度）
.venv/bin/python predict.py ../../build/aerial/model.pkl ../../build/aerial/<id> out.json $J <id>
```

- 2026-11 首次產生：以 18 座 OSM 圖資完整球場訓練。保留 2 座測試：球道約 80% 找到、沙坑約 65–85%、水塘約 70–100%；
  仍會把裸露泥土誤認為沙坑（已排除離球道 60 m 以上者）。
- 下載很慢（每座約 1–3 分鐘），請勿大量平行請求國土測繪中心伺服器。
- App 內須顯示「航照 © 內政部國土測繪中心」（`GolfKit.aerialAttribution`）。
