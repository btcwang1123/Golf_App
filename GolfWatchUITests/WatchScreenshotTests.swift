import XCTest

/// Watch screenshots: launches straight into a demo round.
final class WatchScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureWatchScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestDemo"]
        app.launch()
        sleep(3)
        for (i, name) in ["01-hole", "02-hazards", "03-map", "04-scorecard"].enumerated() {
            if i > 0 { app.swipeUp(); sleep(1) }
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
