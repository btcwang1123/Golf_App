import XCTest

/// Captures App Store screenshots from the showcase data.
/// Run once per device (6.9" and 6.1"), see Tools/AppStore.md.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestShowcase", "-AppleLanguages", "(zh-Hant)"]
        app.launch()

        // Showcase starts automatically: flyover, then shots on hole 1.
        sleep(3)
        snap("01-flyover")
        sleep(5)
        snap("02-round")
        sleep(8)
        snap("03-distances")
        // Let the demo finish to reach the summary.
        let done = app.buttons["開始我的第一場"]
        _ = done.waitForExistence(timeout: 90)
        snap("04-summary")
        if app.buttons["分享成績卡"].exists {
            app.buttons["分享成績卡"].tap()
            sleep(2)
            snap("05-share-card")
        }
    }

    @MainActor
    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
