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
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, maxSwipes: Int = 10) -> Bool {
        if element.waitForExistence(timeout: 2), element.isHittable { return true }
        for _ in 0..<maxSwipes {
            scroll.swipeUp()
            if element.exists, element.isHittable { return true }
        }
        return element.exists && element.isHittable
    }
    private func openReadingLibrary(_ app: XCUIApplication) {
        navigate(app, "Discover")
        let open = app.buttons["openReadingLibrary"]
        XCTAssertTrue(reveal(open, in: app))
        open.tap()
        XCTAssertTrue(app.scrollViews["readingLibraryScroll"].waitForExistence(timeout: 10))
    }
    private func search(_ query: String, in app: XCUIApplication) {
        let field = app.textFields["readingSearch"]
        XCTAssertTrue(reveal(field, in: app.scrollViews["readingLibraryScroll"]))
        field.tap(); field.typeText(query + "\n")
    }
    private func openResult(_ id: String, in app: XCUIApplication) {
        let result = app.buttons["readingResult-\(id)"]
        XCTAssertTrue(reveal(result, in: app.scrollViews["readingLibraryScroll"], maxSwipes: 24))
        result.tap()
        XCTAssertTrue(app.scrollViews["readingReaderScroll"].waitForExistence(timeout: 10))
    }
    private func openContents(_ app: XCUIApplication) {
        let navigation = app.buttons["readingNavigation"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 10)); navigation.tap()
        let contents = app.buttons["Table of contents"]
        XCTAssertTrue(contents.waitForExistence(timeout: 5)); contents.tap()
        XCTAssertTrue(app.scrollViews["readingWorkScroll"].waitForExistence(timeout: 10))
    }
    private func openSection(_ id: String, in app: XCUIApplication) {
        let section = app.buttons["readingSection-\(id)"]
        XCTAssertTrue(reveal(section, in: app.scrollViews["readingWorkScroll"], maxSwipes: 24))
        section.tap()
        XCTAssertTrue(app.scrollViews["readingReaderScroll"].waitForExistence(timeout: 10))
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
        let app = launch(largeText: true); openReadingLibrary(app)
        search("Providas Romanorum", in: app)
        openResult("papal-ben14-bolla-providas-romanorum-text", in: app)
        let notice = app.staticTexts["Unreviewed machine translation from Italian."]
        XCTAssertTrue(reveal(notice, in: app.scrollViews["readingReaderScroll"]))
        capture("readings-translation-notice")
        openContents(app)
        XCTAssertTrue(app.staticTexts["Unreviewed machine translation from Italian."].exists)
        openSection("papal-ben14-bolla-providas-romanorum-summary", in: app)
        let summaryNotice = app.staticTexts["readingEditorialSummaryNotice"]
        XCTAssertTrue(reveal(summaryNotice, in: app.scrollViews["readingReaderScroll"]))
        XCTAssertEqual(summaryNotice.label, "English editorial summary · review pending")
        XCTAssertFalse(app.staticTexts["Unreviewed machine translation from Italian."].exists)
        capture("readings-translation-english-summary")
    }
    func testRecoveredPiusXIIBodySearchContentsAndSavedSummary() throws {
        let app = launch(); openReadingLibrary(app)
        let workID = "papal-pius12-guiding-principles-of-the-lay-apostolate"
        search("European Coal and Steel Authority", in: app)
        openResult("\(workID)-text", in: app)
        XCTAssertTrue(app.staticTexts["Research edition · review pending"].waitForExistence(timeout: 10))
        let heading = app.staticTexts["Principle of Subsidiarity and Complementarity"]
        XCTAssertTrue(reveal(heading, in: app.scrollViews["readingReaderScroll"], maxSwipes: 45))
        capture("readings-recovered-pius-xii-body")
        openContents(app)
        let body = app.buttons["readingSection-\(workID)-text"]
        XCTAssertTrue(reveal(body, in: app.scrollViews["readingWorkScroll"]))
        openSection("\(workID)-summary", in: app)
        let notice = app.staticTexts["readingEditorialSummaryNotice"]
        XCTAssertTrue(reveal(notice, in: app.scrollViews["readingReaderScroll"]))
        XCTAssertEqual(notice.label, "English editorial summary · review pending")
        let summary = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "laypeople are not passive members of the Church")).firstMatch
        XCTAssertTrue(reveal(app.staticTexts["Summary"], in: app.scrollViews["readingReaderScroll"]))
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let save = app.buttons["saveReading"]
        XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        XCTAssertEqual(save.label, "Remove saved reading")
        capture("readings-recovered-pius-xii-summary")
        navigate(app, "My prayer")
        let saved = app.buttons["resource-Saved readings"]
        XCTAssertTrue(reveal(saved, in: app)); saved.tap()
        let bookmark = app.buttons["Guiding Principles Of The Lay Apostolate · English editorial summary"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 10)); bookmark.tap()
        XCTAssertTrue(app.staticTexts["readingEditorialSummaryNotice"].waitForExistence(timeout: 10))
    }
    func testEnglishSummarySearchPreservesAccessToTheLatinSourceAtLargestText() throws {
        let app = launch(largeText: true); openReadingLibrary(app)
        let workID = "papal-ben14-sollicita-ac-provida"
        search("procedural safeguards", in: app)
        openResult("\(workID)-summary", in: app)
        let notice = app.staticTexts["readingEditorialSummaryNotice"]
        XCTAssertTrue(reveal(notice, in: app.scrollViews["readingReaderScroll"]))
        XCTAssertEqual(notice.label, "English editorial summary · review pending")
        XCTAssertFalse(app.staticTexts["Read in Latin"].exists)
        XCTAssertFalse(app.staticTexts["Unreviewed machine translation from Italian."].exists)
        XCTAssertTrue(reveal(app.staticTexts["Summary"], in: app.scrollViews["readingReaderScroll"]))
        let paragraph = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Benedict XIV regulates")).firstMatch
        XCTAssertTrue(paragraph.waitForExistence(timeout: 10)); capture("readings-latin-work-english-summary")
        openContents(app)
        XCTAssertTrue(reveal(app.staticTexts["Read in Latin"], in: app.scrollViews["readingWorkScroll"]))
        openSection("\(workID)-text", in: app)
        XCTAssertTrue(reveal(app.staticTexts["Read in Latin"], in: app.scrollViews["readingReaderScroll"]))
        XCTAssertTrue(app.staticTexts["Research edition · review pending"].exists)
        XCTAssertFalse(app.staticTexts["readingEditorialSummaryNotice"].exists)
        capture("readings-latin-source-still-available")
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
