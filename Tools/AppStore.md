# App Store 上架資料（T51）

> 名稱「高手 / Golf Pro」已定（主畫面顯示名）；App Store 名稱需唯一，建議用「高手高爾夫 – 自動記桿」/「Golf Pro – Auto Scorecard」，上架前請在 App Store Connect 確認未被使用。

## 名稱 / 副標
- 繁中：**高手高爾夫**　副標：手錶自動記桿・全台球場距離
- English: **Golf Pro – Auto Scorecard**　Subtitle: Auto stroke count & yardages

## 關鍵字
- 繁中：高爾夫,記桿,計分卡,距離,果嶺,Apple Watch,球場,碼數,GPS,揮桿,差點,成績
- English: golf,scorecard,gps,rangefinder,yardage,apple watch,swing,handicap,stats,course

## 描述（繁中）
不用註冊，下載就能用的高爾夫記桿 App。

- Apple Watch 偵測揮桿自動 +1，推桿手動補一下就好
- 全台球場與精選球場 2.5D 球道圖：到果嶺前、中、後與障礙物距離
- 任意點測距、旗桿位置、天氣與風向、依你自己的距離建議選桿
- 同組最多四人一起記分：比桿、Stableford、比洞、Skins
- 打完一鍵產生成績卡，分享到 LINE、IG 或相簿
- 進階統計：成績趨勢、FIR / GIR、推桿、球桿距離、Strokes Gained（估算）
- 資料只存在你的手機，不需要帳號

## Description (English)
Golf scoring with no sign-up.

- Apple Watch detects your swings and counts strokes; just tap to add putts
- 2.5D hole maps for Taiwan courses with front / middle / back and hazard distances
- Tap-anywhere yardages, pin positions, wind, and club advice from your own distances
- Score for up to four players: stroke play, Stableford, match play and skins
- Share a beautiful scorecard image when you finish
- Insights: trends, fairways and greens hit, putting, club distances and estimated Strokes Gained
- Your data stays on your phone — no account needed

## 隱私權政策文字
本 App 不收集、不上傳任何個人資料，也不追蹤使用者。定位、動作與健康資料只在裝置上用來計算距離、偵測揮桿與記錄體能訓練。
回合、球場與設定儲存在你的裝置；只有在你主動分享檔案或圖片時才會離開裝置。當機與效能報告（MetricKit）只存在本機，需由你手動分享。

Privacy: The app does not collect, upload or track any personal data. Location, motion and health data are used on device only. Rounds, courses and settings stay on your device unless you share a file or image yourself.

App Privacy (App Store Connect)：**Data Not Collected**。Privacy manifests：`GolfApp/Resources/PrivacyInfo.xcprivacy`、`GolfWatch/Resources/PrivacyInfo.xcprivacy`。

## 必要標示
- 地圖資料：© OpenStreetMap contributors（ODbL）— App 內球場列表、球場頁、地圖右下角、設定、分享卡。
- 天氣： Weather 標示與法律連結 — 回合畫面風向標籤、設定頁。WeatherKit 需在 Apple Developer 開啟 capability。

## 截圖
UI 測試以展示資料截圖（附件在 .xcresult 中）：
```
xcodebuild test -scheme GolfApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:GolfAppUITests/ScreenshotTests
xcodebuild test -scheme GolfApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GolfAppUITests/ScreenshotTests
xcodebuild test -scheme GolfWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' -only-testing:GolfWatchUITests
```
匯出：`xcrun xcresulttool export attachments --path <result>.xcresult --output-path Screenshots/`

## 手動待辦
- Apple Developer 帳號、App ID、bundle id（目前 `com.bobby.golfapp`）、App Group `group.com.bobby.golfapp`、WeatherKit
- App Store Connect 建立 App、上傳截圖、TestFlight 給推廣前的種子使用者
