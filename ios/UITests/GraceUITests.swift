import XCTest

@MainActor final class GraceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(skipWelcome: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"] + (skipWelcome ? ["--skip-welcome"] : [])
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Not Now"].exists { springboard.buttons["Not Now"].tap() }
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func navigate(_ app: XCUIApplication, _ title: String) {
        if app.tabBars.buttons[title].exists { app.tabBars.buttons[title].tap() }
        else { app.staticTexts[title].firstMatch.tap() }
    }
    func testGuestStartsPrayerAndReadsWithoutPermissionPrompt() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["beginPraying"].waitForExistence(timeout: 10)); capture(app, "01-welcome"); app.buttons["beginPraying"].tap()
        XCTAssertTrue(app.buttons["prayNow"].waitForExistence(timeout: 5))
        capture(app, "02-today"); app.buttons["prayNow"].tap()
        XCTAssertTrue(app.buttons["mainPlayback"].waitForExistence(timeout: 10))
        capture(app, "06-player")
        app.swipeUp()
        app.buttons["Read along"].tap()
        XCTAssertTrue(app.staticTexts["Reading size"].waitForExistence(timeout: 5))
        capture(app, "07-read-along")
        XCTAssertEqual(app.alerts.count, 0)
    }
    func testSearchAndPrivateIntentionFlow() throws {
        let app = launch(skipWelcome: true)
        navigate(app, "Discover")
        capture(app, "03-discover")
        app.buttons["openSearch"].tap()
        let search = app.textFields["prayerSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("doesnotexist")
        XCTAssertTrue(app.staticTexts["A little more room to look"].waitForExistence(timeout: 5))
        app.buttons["Clear search & filters"].tap()
        navigate(app, "My prayer")
        capture(app, "11-my-prayer")
        app.buttons["resource-My intentions"].tap()
        capture(app, "23-empty-intentions")
        app.buttons["addIntention"].tap()
        let title = app.textFields["intentionTitle"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("A private hope")
        app.buttons["saveIntention"].tap()
        XCTAssertTrue(app.staticTexts["A private hope"].waitForExistence(timeout: 5))
        capture(app, "13-intentions")
    }
    func testSaveAndDownloadAreIndependent() throws {
        let app = launch(skipWelcome: true)
        navigate(app, "Discover")
        app.buttons["openSearch"].tap()
        let search = app.textFields["prayerSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Morning offering\n")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Morning offering")).firstMatch.tap()
        XCTAssertTrue(app.buttons["savePrayer"].waitForExistence(timeout: 5)); app.buttons["savePrayer"].tap()
        capture(app, "05-prayer-detail")
        app.swipeUp()
        app.buttons["downloadPrayer"].tap()
        XCTAssertTrue(app.staticTexts["Available offline"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["savePrayer"].label, "Remove saved prayer")
    }
    func testScriptureAndGuidedRosary() throws {
        let app = launch(skipWelcome: true)
        navigate(app, "Scripture")
        XCTAssertTrue(app.staticTexts["Reading size"].waitForExistence(timeout: 5))
        capture(app, "09-scripture")
        navigate(app, "Discover")
        app.buttons["openSearch"].tap()
        let search = app.textFields["prayerSearch"]; search.tap(); search.typeText("Joyful\n")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "The Joyful Mysteries")).firstMatch.tap()
        let guide = app.buttons["Open the guided Rosary"]
        for _ in 0..<4 where !guide.isHittable { app.swipeUp() }
        guide.tap()
        XCTAssertTrue(app.staticTexts["Sign of the Cross"].waitForExistence(timeout: 5))
        capture(app, "08-rosary")
        let next = app.buttons["Next Rosary prayer"]
        for _ in 0..<4 where !next.isHittable { app.swipeUp() }
        next.tap()
        XCTAssertTrue(app.staticTexts["Apostles’ Creed"].waitForExistence(timeout: 5))
    }
}
