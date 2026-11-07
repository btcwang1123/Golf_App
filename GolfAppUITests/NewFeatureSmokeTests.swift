import XCTest

/// Walks the screens added for bets, achievements, recap, stats, game plan, tee times and scorecard scan.
final class NewFeatureSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testNewScreensOpen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSkipOnboarding", "-AppleLanguages", "(zh-Hant)"]
        app.launch()

        // Stats: achievements, recap, tempo & range.
        app.tabBars.buttons["統計"].tap()
        tapText(app, "成就")
        XCTAssertTrue(app.staticTexts["已解鎖"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tapText(app, "回顧")
        XCTAssertTrue(app.navigationBars["回顧"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tapText(app, "揮桿節奏與練習場")
        XCTAssertTrue(app.staticTexts["練習場紀錄"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Course: game plan and tee time reminder.
        app.tabBars.buttons["球場"].tap()
        if app.buttons["稍後再說"].waitForExistence(timeout: 2) { app.buttons["稍後再說"].tap() }
        tapText(app, "臺灣高爾夫俱樂部球場")
        let plan = app.buttons["攻略規劃"]
        for _ in 0..<4 where !plan.isHittable { app.swipeUp() }
        plan.tap()
        XCTAssertTrue(app.navigationBars["攻略規劃"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let tee = app.buttons["開球提醒"]
        for _ in 0..<4 where !tee.isHittable { app.swipeUp() }
        tee.tap()
        XCTAssertTrue(app.navigationBars["預約開球提醒"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()

        // Manual entry: scorecard scan.
        app.tabBars.buttons["歷史"].tap()
        let manual = app.buttons["手動記錄成績"]
        if manual.waitForExistence(timeout: 3) { manual.tap() } else { app.navigationBars.buttons.element(boundBy: 0).tap() }
        tapText(app, "掃描紙本記分卡")
        XCTAssertTrue(app.navigationBars["掃描記分卡"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func tapText(_ app: XCUIApplication, _ text: String) {
        let button = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if button.waitForExistence(timeout: 5) {
            button.tap()
        } else {
            let label = app.staticTexts[text]
            XCTAssertTrue(label.waitForExistence(timeout: 5), "missing \(text)")
            label.tap()
        }
    }
}
