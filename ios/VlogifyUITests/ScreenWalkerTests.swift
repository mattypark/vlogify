import XCTest

/// Every screen, every button, a screenshot per state. Pass or fail, the attachment
/// is kept -- the morning report is the pictures, not the green ticks.
///
/// Each test is one journey from a fresh launch so a failure in one does not hide
/// the others, and each names its screenshots `NN-screen-state` so the matrix
/// script can lay them out in order.
final class ScreenWalkerTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    // MARK: Onboarding

    func testLanguageIsAskedAfterSignIn() {
        let app = XCUIApplication()
        app.launchArguments += ["-vlogifyUITest", "-vlogifyDemo", "empty", "-vlogifyPermissions", "unasked"]
        app.launch()
        wait(for: app.buttons["welcome.skip"])
        snap(app, "00-welcome")
        app.buttons["welcome.skip"].tap()
        wait(for: app.any("screen.language"), 8)
        snap(app, "00-language")
        app.buttons["language.ko"].tap()
        snap(app, "00-language-ko")
        app.buttons["language.continue"].tap()
        wait(for: app.buttons["permissions.continue"], 8)
        XCTAssertTrue(app.buttons["permissions.continue"].label.contains("계속"), "permissions must be in Korean after choosing 한국어, got \(app.buttons["permissions.continue"].label)")
        snap(app, "00-permissions-after-ko")
    }

    func testWelcomeAndEmailSignIn() {
        let app = XCUIApplication.vlogify(demo: "empty", permissions: "unasked")
        app.launch()
        wait(for: app.buttons["welcome.apple"])
        snap(app, "01-welcome")

        app.buttons["welcome.email"].tap()
        wait(for: app.textFields["email.address"])
        snap(app, "02-email-address")
        app.textFields["email.address"].tap()
        app.textFields["email.address"].typeText("not an email")
        XCTAssertFalse(app.buttons["email.submit"].isEnabled, "invalid email must disable submit")
        app.textFields["email.address"].tap()
        app.textFields["email.address"].typeText(XCUIKeyboardKey.delete.rawValue)
        clear(app.textFields["email.address"])
        app.textFields["email.address"].typeText("review@vlogify.app")
        app.buttons["email.submit"].tap()
        wait(for: app.textFields["email.code"])
        snap(app, "03-email-code")
        app.textFields["email.code"].typeText("123456")
        app.buttons["email.submit"].tap()
        wait(for: app.any("email.error"))
        snap(app, "04-email-wrong-code")
        clear(app.textFields["email.code"])
        app.textFields["email.code"].typeText("000000")
        app.buttons["email.submit"].tap()

        wait(for: app.any("screen.permissions"), 8)
        snap(app, "05-permissions")
        for _ in 0..<4 {
            wait(for: app.buttons["permissions.continue"], 8)
            app.buttons["permissions.continue"].tap()
        }
        wait(for: app.any("screen.home"), 8)
        snap(app, "06-home-after-signin")
    }

    func testAppleAndGoogleButtonsSignIn() {
        let app = XCUIApplication.vlogify(demo: "empty")
        app.launch()
        wait(for: app.buttons["welcome.google"])
        app.buttons["welcome.google"].tap()
        // Permissions are forced granted and the mock profile has a name, so this
        // lands straight on the empty home.
        wait(for: app.any("home.empty"), 8)
        snap(app, "07-google-signed-in")
    }

    // MARK: Home and rooms

    func testHomeFullAndRoomTimeline() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17)
        app.launch()
        wait(for: app.any("screen.home"))
        snap(app, "10-home-full")

        let card = app.buttons["home.room.room-2"]
        wait(for: card)
        card.tap()
        wait(for: app.any("screen.room"))
        snap(app, "11-room-today")
        app.buttons["room.menu"].tap()
        wait(for: app.buttons["history"])
        snap(app, "12-room-menu")
        app.buttons["history"].tap()
        wait(for: app.any("screen.history"))
        snap(app, "13-history")
        let day = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history.day.'")).element(boundBy: 1)
        if day.waitForExistence(timeout: 3) {
            day.tap()
            wait(for: app.buttons["room.today"])
            snap(app, "14-room-past-day")
            app.buttons["room.today"].tap()
        }
        app.buttons["room.invite"].tap()
        wait(for: app.any("invite.code"))
        snap(app, "15-invite")
        app.buttons["invite.copy"].tap()
        app.buttons["invite.done"].tap()
    }

    func testNewRoomAndJoin() {
        let app = XCUIApplication.vlogify(demo: "solo")
        app.launch()
        wait(for: app.any("screen.home"))
        app.buttons["bar.plus"].tap()
        wait(for: app.buttons["create a room"])
        snap(app, "20-plus-menu")
        app.buttons["create a room"].tap()
        wait(for: app.any("screen.newRoom"))
        snap(app, "21-new-room")
        app.textFields["newRoom.name"].tap()
        app.textFields["newRoom.name"].typeText("walker room\n")
        app.buttons["newRoom.size.4"].tap()
        app.buttons["newRoom.type.vlog"].tap()
        snap(app, "22-new-room-vlog")
        app.buttons["newRoom.type.log"].tap()
        app.buttons["newRoom.size.20"].tap()
        snap(app, "23-new-room-6-20")
        app.buttons["newRoom.create"].tap()
        wait(for: app.any("invite.code"), 8)
        snap(app, "24-invite-after-create")
        app.buttons["invite.done"].tap()
        wait(for: app.any("screen.room"), 8)
        snap(app, "25-new-room-timeline")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["bar.plus"].tap()
        wait(for: app.buttons["join with code"])
        app.buttons["join with code"].tap()
        wait(for: app.any("screen.join"))
        snap(app, "26-join")
        app.textFields["join.code"].typeText("ZZZZZZ")
        wait(for: app.any("join.error"))
        snap(app, "27-join-bad-code")
        app.buttons["join.close"].tap()
    }

    // MARK: Camera

    func testCameraCaptureAndAlreadyPosted() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17, screen: "camera")
        app.launch()
        wait(for: app.any("screen.camera"))
        snap(app, "30-camera")
        app.buttons["camera.room"].tap()
        let logRoom = app.buttons.matching(identifier: "lololol testing").firstMatch
        if logRoom.waitForExistence(timeout: 3) { logRoom.tap() }
        wait(for: app.buttons["camera.shutter"])
        app.buttons["bar.flip"].tap()
        app.buttons["bar.flash"].tap()
        if app.buttons["camera.rotateHint"].exists { app.buttons["camera.rotateHint"].tap() }
        app.buttons["camera.shutter"].tap()
        wait(for: app.any("toast"), 10)
        snap(app, "31-camera-posted-toast")
        wait(for: app.any("camera.posted"), 10)
        snap(app, "32-camera-already-posted")
        XCTAssertFalse(app.buttons["camera.shutter"].isEnabled, "one clip per hour")
    }

    func testCameraDenied() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17, screen: "camera", permissions: "denied")
        app.launch()
        wait(for: app.any("camera.denied"))
        snap(app, "33-camera-denied")
    }

    // MARK: Playback and export

    func testDayPlayerComposes() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17)
        app.launch()
        let card = app.buttons["home.room.room-2"]
        wait(for: card)
        card.tap()
        wait(for: app.any("screen.room"))
        app.buttons["room.menu"].tap()
        wait(for: app.buttons["play the day"])
        app.buttons["play the day"].tap()
        wait(for: app.any("screen.dayPlayer"))
        snap(app, "40-day-player-stitching")
        let save = app.buttons["dayPlayer.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 60), "stitch should finish within a minute")
        snap(app, "41-day-player-ready")
        app.buttons["dayPlayer.close"].tap()
    }

    // MARK: Profile, safety, legal

    func testProfileSettingsAndDeleteAccount() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17)
        app.launch()
        wait(for: app.buttons["home.profile"])
        app.buttons["home.profile"].tap()
        wait(for: app.any("screen.profile"))
        snap(app, "50-profile")
        XCTAssertTrue(app.buttons["legal.privacy"].exists, "privacy policy link in-app (5.1.1)")
        XCTAssertTrue(app.buttons["legal.terms"].exists)
        XCTAssertTrue(app.buttons["legal.support"].exists)
        app.buttons["settings.blocked"].tap()
        wait(for: app.any("screen.blocked"))
        snap(app, "51-blocked-empty")
        app.buttons["close"].tap()
        // The list is lazy; the delete row is not in the hierarchy until scrolled to.
        app.swipeUp()
        app.swipeUp()
        wait(for: app.buttons["account.delete"])
        app.buttons["account.delete"].tap()
        wait(for: app.buttons.matching(identifier: "account.deleteConfirm").firstMatch)
        snap(app, "52-delete-confirm")
        app.buttons.matching(identifier: "account.deleteConfirm").firstMatch.tap()
        wait(for: app.buttons["welcome.apple"], 8)
        snap(app, "53-after-delete")
    }

    func testReportAndBlock() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17)
        app.launch()
        let card = app.buttons["home.room.room-2"]
        wait(for: card)
        card.tap()
        wait(for: app.any("screen.room"))
        let tile = app.descendants(matching: .any).matching(NSPredicate(format: "label ENDSWITH \"'s clip\" AND NOT label BEGINSWITH 'matthew'")).firstMatch
        wait(for: tile)
        tile.press(forDuration: 1.0)
        wait(for: app.buttons["report"])
        snap(app, "60-tile-context-menu")
        app.buttons["report"].tap()
        wait(for: app.any("screen.report"))
        snap(app, "61-report")
        // The sheet opens at the medium detent; the toggle is below the fold.
        app.swipeUp()
        wait(for: app.switches["report.block"])
        app.switches["report.block"].tap()
        app.buttons["report.send"].tap()
        wait(for: app.any("toast"))
        snap(app, "62-reported-and-blocked")
    }

    func testNotificationsSheet() {
        let app = XCUIApplication.vlogify(demo: "full", hour: 17)
        app.launch()
        wait(for: app.buttons["bar.bell"])
        app.buttons["bar.bell"].tap()
        wait(for: app.any("screen.notifications"))
        snap(app, "70-notifications")
    }

    // MARK: Localisation

    func testEveryLanguageRendersWelcomeAndHome() {
        for locale in ["ko", "ja", "zh-Hant", "vi", "ru"] {
            let app = XCUIApplication.vlogify(demo: "full", hour: 17, locale: locale)
            app.launch()
            wait(for: app.any("screen.home"))
            XCTAssertFalse(app.buttons["bar.segment.logs"].label == "logs" && locale != "en", "\(locale) still shows English chrome")
            snap(app, "80-home-\(locale)")
            app.buttons["bar.plus"].tap()
            let create = app.buttons.element(boundBy: 0)
            _ = create.waitForExistence(timeout: 3)
            snap(app, "81-plus-menu-\(locale)")
            app.terminate()
        }
    }

    private func clear(_ field: XCUIElement) {
        guard let value = field.value as? String, !value.isEmpty else { return }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 2))
    }
}
