# 精選球場資料（featured）

每個 `*.json` 是一座完整的 `Course`（`source` 載入時會被設為 `featured`），啟動時背景載入，
優先序 **user > featured > osm**；`replaces` 填被取代的 OSM 球場 id，列表與搜尋不會重複。

## 資料來源規則（只收以下三種）
| provenance | 來源 | 可打包 |
|---|---|---|
| `osm` | OpenStreetMap（以 OSM 允許的影像描繪，ODbL，需顯示 © OpenStreetMap contributors） | ✅ |
| `survey` | App 的「實地踩點模式」在現場以 GPS 平均值量測 | ✅ |
| `licensed` | 球場書面授權的球道圖 | ✅ |
| `userTraced` | 在 Apple / Google 衛星圖上手繪 | ❌ 不收錄 |

**不收錄從 Apple / Google 衛星圖描繪的資料**（Apple 地圖條款不允許散布）。

## 新增一座
```
swift run --package-path GolfKit course-audit GolfApp/Resources/courses_tw.json \
    --promote <osm-id> --out GolfApp/Resources/featured/<name>.json --id featured-<name>
swift run --package-path GolfKit course-audit GolfApp/Resources/courses_tw.json --featured GolfApp/Resources/featured
```
目標：`course-audit` 結果為 `full`。踩點資料：在 App 匯出 `.golfcourse`，取出 `course` 物件，
`provenance` 須為 `survey`，再放到此資料夾。

## 目前收錄
- `taiwan-golf-club.json` — 臺灣高爾夫俱樂部球場（OSM，16 洞，full）
