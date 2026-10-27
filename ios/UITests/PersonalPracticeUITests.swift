import XCTest

@MainActor final class PersonalPracticeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func open(_ resource: String) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--skip-welcome"]; app.launch()
        XCUIDevice.shared.orientation = .portrait
        if app.tabBars.buttons["My prayer"].waitForExistence(timeout: 10) { app.tabBars.buttons["My prayer"].tap() }
        else { app.staticTexts["My prayer"].firstMatch.tap() }
        let button = app.buttons["resource-\(resource)"]
        reveal(button, app: app); button.tap(); return app
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        for _ in 0..<12 where !element.isHittable { app.swipeDown() }
        XCTAssertTrue(element.waitForExistence(timeout: 5)); XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testActivityCalendarNavigationInLandscape() {
        let app = open("Prayer activity")
        XCUIDevice.shared.orientation = .landscapeLeft
        let previous = app.buttons["previousActivityMonth"]
        for _ in 0..<30 where !previous.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.70)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.50)))
        }
        XCTAssertTrue(previous.isHittable); previous.tap()
        let next = app.buttons["nextActivityMonth"]
        XCTAssertTrue(next.isEnabled); next.tap(); XCTAssertFalse(next.isEnabled)
        capture("practice-activity-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
    func testCreateOrderedRoutineAndRecordPrayer() {
        let app = open("Prayer routines")
        app.buttons["createRoutine"].tap()
        let name = app.textFields["routineName"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Quiet mornings\n")
        let add = app.buttons["addRoutinePrayers"]; reveal(add, app: app); add.tap()
        app.buttons["Our Father"].tap(); app.buttons["Hail Mary"].tap(); app.buttons["Done"].tap()
        app.buttons["saveRoutine"].tap()
        app.staticTexts["Quiet mornings"].firstMatch.tap()
        let mark = app.buttons["Mark prayed today"].firstMatch; reveal(mark, app: app); mark.tap()
        app.swipeDown(); app.swipeDown()
        XCTAssertTrue(app.staticTexts["1 of 2 prayed today"].waitForExistence(timeout: 5)); capture("practice-routine")
    }
    func testCreateFlexibleWeeklyGoal() {
        let app = open("Personal goals")
        app.buttons["addGoal"].tap()
        let title = app.textFields["goalName"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Three quiet days")
        app.buttons["saveGoal"].tap()
        XCTAssertTrue(app.staticTexts["Three quiet days"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 of 3 days this week"].exists); capture("practice-goal")
    }
    func testManualPrayerAppearsInActivityCalendar() {
        let app = open("Prayer activity")
        let log = app.buttons["logManualPrayer"]; reveal(log, app: app); log.tap()
        let title = app.textFields["manualPrayerTitle"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("A quiet walk")
        app.buttons["saveManualPrayer"].tap()
        let prayer = app.staticTexts["A quiet walk"]; reveal(prayer, app: app)
        XCTAssertTrue(prayer.exists); capture("practice-manual-activity")
    }
    func testJournalWritingSearchAndExportPreview() {
        let app = open("Prayer journal")
        app.buttons["writeJournalEntry"].tap()
        let title = app.textFields["journalTitle"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("A small gratitude")
        let body = app.textViews["journalBody"]; body.tap(); body.typeText("Synthetic private journal writing.")
        app.buttons["saveJournal"].tap()
        XCTAssertTrue(app.staticTexts["A small gratitude"].waitForExistence(timeout: 5)); app.staticTexts["A small gratitude"].tap()
        app.buttons["Journal entry options"].tap(); app.buttons["Export entry"].tap()
        XCTAssertTrue(app.buttons["Share readable copy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Save a text file"].exists); capture("practice-journal-export")
    }
    func testIntentionUpdatesAndPrivateExport() {
        let app = open("My intentions")
        let add = app.buttons["addIntention"]; reveal(add, app: app); add.tap()
        let title = app.textFields["intentionTitle"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("A synthetic hope")
        app.buttons["saveIntention"].tap()
        app.staticTexts["A synthetic hope"].firstMatch.tap()
        let update = app.textViews["intentionUpdate"]; reveal(update, app: app); update.tap(); update.typeText("A synthetic follow-up reflection.")
        app.buttons["Done"].tap()
        let save = app.buttons["saveIntentionUpdate"]; reveal(save, app: app); save.tap()
        XCTAssertTrue(app.staticTexts["A synthetic follow-up reflection."].waitForExistence(timeout: 5))
        app.buttons["Intention options"].tap(); app.buttons["Export intention"].tap()
        XCTAssertTrue(app.buttons["Share readable copy"].waitForExistence(timeout: 5)); capture("practice-intention-export")
    }
}
