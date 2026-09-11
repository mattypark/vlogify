import XCTest

/// The numbers the morning report leads with: how fast the app opens, how fast the
/// three things people actually do are. XCTest's metrics API runs each block five
/// times and reports median and deviation into the result bundle.
final class MetricTests: XCTestCase {
    /// Cold launch to first frame, five runs.
    func testColdLaunch() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17)
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            app.launch()
        }
    }

    /// Tap the camera tab until the preview is on screen.
    func testOpenCamera() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17)
        app.launch()
        wait(for: app.buttons["bar.segment.camera"])
        measure(metrics: [XCTClockMetric()]) {
            app.buttons["bar.segment.camera"].tap()
            _ = app.any("screen.camera").waitForExistence(timeout: 5)
            app.buttons["bar.segment.logs"].tap()
            _ = app.any("screen.home").waitForExistence(timeout: 5)
        }
    }

    /// Shutter tap until the "posted" toast: record, write, upload, post.
    func testRecordToPosted() {
        measure(metrics: [XCTClockMetric()]) {
            let app = XCUIApplication.vlogify(demo: "solo", hour: 17, screen: "camera")
            app.launch()
            _ = app.buttons["camera.shutter"].waitForExistence(timeout: 5)
            app.buttons["camera.shutter"].tap()
            _ = app.any("toast").waitForExistence(timeout: 15)
            app.terminate()
        }
    }

    /// Open the day player until the save button appears: the whole stitch.
    func testStitchDay() {
        measure(metrics: [XCTClockMetric()]) {
            let app = XCUIApplication.vlogify(demo: "full", hour: 17)
            app.launch()
            let card = app.buttons["home.room.room-2"]
            _ = card.waitForExistence(timeout: 10)
            card.tap()
            _ = app.buttons["room.menu"].waitForExistence(timeout: 5)
            app.buttons["room.menu"].tap()
            _ = app.buttons["play the day"].waitForExistence(timeout: 3)
            app.buttons["play the day"].tap()
            _ = app.buttons["dayPlayer.save"].waitForExistence(timeout: 60)
            app.terminate()
        }
    }
}
