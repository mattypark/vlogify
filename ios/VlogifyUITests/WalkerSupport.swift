import XCTest

/// Shared helpers for the overnight walker. Every test launches through here so the
/// demo scenario, the hour and the UI-test flag are always set the same way.
extension XCUIApplication {
    static func vlogify(demo: String = "full", hour: Int = 17, screen: String? = nil,
                        permissions: String = "granted", locale: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-vlogifyUITest", "-vlogifyDemo", demo, "-vlogifyHour", String(hour),
                                "-vlogifyPermissions", permissions]
        if let screen { app.launchArguments += ["-vlogifyScreen", screen] }
        if let locale { app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale] }
        return app
    }
}

extension XCTestCase {
    /// Attaches a full-screen PNG under a stable name so the matrix script can export
    /// it as `screens/<name>.png`.
    func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for an element and fails the test with the element's identifier in the
    /// message, which is what the morning report groups on.
    @discardableResult
    func wait(for element: XCUIElement, _ seconds: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let ok = element.waitForExistence(timeout: seconds)
        XCTAssertTrue(ok, "missing: \(element)", file: file, line: line)
        return ok
    }
}
