import XCTest

@MainActor final class ReadingLibraryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--skip-welcome"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        return app
    }
    private func navigate(_ app: XCUIApplication, _ title: String) {
        if app.tabBars.buttons[title].exists { app.tabBars.buttons[title].tap() }
        else if app.buttons[title].firstMatch.exists { app.buttons[title].firstMatch.tap() }
        else { app.staticTexts[title].firstMatch.tap() }
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testTopicSearchOpensAnOfflineReadingAndSavesIt() throws {
        let app = launch(); navigate(app, "Discover")
        let open = app.buttons["openReadingLibrary"]; XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        let search = app.textFields["readingSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("suffering\n")
        let result = app.buttons["readingResult-drb-rom-8"]
        for _ in 0..<6 where !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 10)); capture("readings-suffering-search"); result.tap()
        XCTAssertTrue(app.staticTexts["Romans 8"].firstMatch.waitForExistence(timeout: 10))
        let save = app.buttons["saveReading"]; XCTAssertTrue(save.exists); save.tap()
        XCTAssertEqual(save.label, "Remove saved reading"); capture("readings-offline-chapter")
        navigate(app, "My prayer")
        let saved = app.buttons["resource-Saved readings"]; XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(app.buttons["Romans 8"].waitForExistence(timeout: 5)); capture("readings-saved")
    }
    func testFullBibleHasDeuterocanonicalBooksAndChapterNavigation() throws {
        let app = launch(); navigate(app, "Scripture")
        let open = app.buttons["openFullBible"]; XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        let search = app.textFields["readingSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Tobias 1\n")
        let result = app.buttons["readingResult-drb-tob-1"]; XCTAssertTrue(result.waitForExistence(timeout: 10)); result.tap()
        XCTAssertTrue(app.staticTexts["Tobias 1"].firstMatch.waitForExistence(timeout: 10)); capture("readings-tobias")
        app.buttons["readingNavigation"].tap(); app.buttons["Next chapter"].tap()
        XCTAssertTrue(app.staticTexts["Tobias 2"].firstMatch.waitForExistence(timeout: 10))
    }
    func testModernEncyclicalReadsOfflineWithSourceAndResearchEditionLabel() throws {
        let app = launch(); navigate(app, "Discover"); app.buttons["openReadingLibrary"].tap()
        let search = app.textFields["readingSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Spe salvi\n")
        let result = app.buttons["readingResult-papal-ben16-spe-salvi-text"]; XCTAssertTrue(result.waitForExistence(timeout: 10)); result.tap()
        XCTAssertTrue(app.staticTexts["Research edition · review pending"].waitForExistence(timeout: 5))
        let paragraph = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "in hope we were saved")).firstMatch
        for _ in 0..<5 where !paragraph.isHittable { app.swipeUp() }
        XCTAssertTrue(paragraph.exists); capture("readings-offline-encyclical")
        app.buttons["readingNavigation"].tap(); app.buttons["Table of contents"].tap()
        let source = app.descendants(matching: .any).matching(identifier: "readingSourceLink").firstMatch
        for _ in 0..<5 where !source.isHittable { app.swipeUp() }
        XCTAssertTrue(source.exists)
    }
    func testResearchTranslationIsLabeledBeforeReading() throws {
        let app = launch(largeText: true); navigate(app, "Discover")
        let open = app.buttons["openReadingLibrary"]
        for _ in 0..<6 where !open.isHittable { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        let search = app.textFields["readingSearch"]
        for _ in 0..<6 where !search.isHittable { app.swipeUp() }
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Providas Romanorum\n")
        let result = app.buttons["readingResult-papal-ben14-bolla-providas-romanorum-text"]
        for _ in 0..<6 where !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 10)); result.tap()
        let notice = app.staticTexts["Unreviewed machine translation from Italian."]
        for _ in 0..<4 where !notice.isHittable { app.swipeUp() }
        XCTAssertTrue(notice.waitForExistence(timeout: 5)); capture("readings-translation-notice")
    }
    func testReaderWithLargestTextAndDarkAppearance() throws {
        let app = launch(largeText: true)
        navigate(app, "My prayer"); app.buttons["Settings"].tap()
        let appearance = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Appearance")).firstMatch
        XCTAssertTrue(appearance.waitForExistence(timeout: 5)); appearance.tap(); app.buttons["Dark"].tap()
        navigate(app, "Scripture")
        let open = app.buttons["openFullBible"]
        for _ in 0..<6 where !open.isHittable { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        let search = app.textFields["readingSearch"]
        for _ in 0..<6 where !search.isHittable { app.swipeUp() }
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Tobias 1\n")
        let result = app.buttons["readingResult-drb-tob-1"]
        for _ in 0..<6 where !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 10)); capture("readings-largest-text-search"); result.tap()
        XCTAssertTrue(app.staticTexts["Tobias 1"].firstMatch.waitForExistence(timeout: 10)); capture("readings-largest-text-reader")
        app.buttons["saveReading"].tap(); XCTAssertEqual(app.buttons["saveReading"].label, "Remove saved reading")
    }
    func testBibleReferenceOpensAtTheRequestedVerse() throws {
        let app = launch(); navigate(app, "Scripture"); app.buttons["openFullBible"].tap()
        let search = app.textFields["readingSearch"]; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Romans 8:18\n")
        let result = app.buttons["readingResult-drb-rom-8"]; XCTAssertTrue(result.waitForExistence(timeout: 10)); result.tap()
        let verse = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "For I reckon that the sufferings")).firstMatch
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: verse)
        waitForExpectations(timeout: 10); capture("readings-bible-reference")
    }
}
