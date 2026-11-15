import XCTest

/// End-to-end checks of the main flows plus Xcode's automated accessibility audit
/// (XCUIApplication.performAccessibilityAudit, iOS 17+). These run in the iOS Simulator;
/// they do not replace testing with VoiceOver on a real iPhone.
final class ATGuideUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ATGuideUITesting"]
        app.launch()
    }

    // MARK: Helpers

    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "tab \(name)")
        button.tap()
    }

    /// A list row or link whose spoken label starts with `prefix`.
    private func row(startingWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Taps a row, scrolling down first if the list has not loaded it yet.
    private func tapRow(_ prefix: String) {
        let element = row(startingWith: prefix)
        _ = element.waitForExistence(timeout: 5)
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists, "row starting with \(prefix)")
        element.tap()
    }

    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func openNotetaker(_ name: String) {
        tab("Browse")
        tapRow("Notetakers")
        tapRow(name)
        XCTAssertTrue(app.staticTexts["Overview"].waitForExistence(timeout: 10))
    }

    private func audit(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        guard #available(iOS 17.0, *) else { return }
        do {
            try app.performAccessibilityAudit { issue in
                // Log every issue so the CI log lists them, then let XCTest fail on it.
                print("Accessibility audit, \(screen): \(issue.auditType) \(issue.compactDescription) element: \(String(describing: issue.element?.label))")
                return false
            }
        } catch {
            XCTFail("Audit on \(screen) could not run: \(error)", file: file, line: line)
        }
    }

    // MARK: Flows

    func testFiveTabsAreLabeled() {
        for name in ["Browse", "Search", "Favorites", "Compare", "More"] {
            XCTAssertTrue(app.tabBars.buttons[name].waitForExistence(timeout: 10), name)
        }
    }

    func testBrowseCategoryToDevice() {
        openNotetaker("VersaBraille")
        for heading in ["Specs", "History", "Sources"] {
            let text = app.staticTexts[heading]
            XCTAssertTrue(text.exists, heading)
        }
        XCTAssertTrue(app.buttons["Favorite"].exists)
        XCTAssertTrue(app.buttons["Add to Compare"].exists)
    }

    func testFavoriteAppearsInFavorites() {
        openNotetaker("VersaBraille")
        app.buttons["Favorite"].tap()
        tab("Favorites")
        XCTAssertTrue(row(startingWith: "VersaBraille").waitForExistence(timeout: 10))
    }

    func testRecentlyViewedOnBrowse() {
        openNotetaker("VersaBraille")
        goBack()
        goBack()
        XCTAssertTrue(app.staticTexts["Recently Viewed"].waitForExistence(timeout: 10))
        XCTAssertTrue(row(startingWith: "VersaBraille").exists)
    }

    func testSearchFindsBrailleNote() {
        tab("Search")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("BrailleNote Touch")
        XCTAssertTrue(app.staticTexts["resultCount"].waitForExistence(timeout: 10))
        XCTAssertTrue(row(startingWith: "BrailleNote Touch").waitForExistence(timeout: 10))
    }

    func testCompareTwoDevices() {
        openNotetaker("VersaBraille")
        app.buttons["Add to Compare"].tap()
        XCTAssertTrue(app.buttons["Remove from Compare"].waitForExistence(timeout: 5))
        goBack()
        tapRow("Keynote talking word processor")
        XCTAssertTrue(app.buttons["Add to Compare"].waitForExistence(timeout: 10))
        app.buttons["Add to Compare"].tap()
        tab("Compare")
        XCTAssertTrue(app.switches["Show only differences"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Processor"].exists)
        XCTAssertTrue(row(startingWith: "Device 1: VersaBraille").exists)
        audit("Compare with two devices")
    }

    func testCompareAddDeviceSheet() {
        tab("Compare")
        let add = app.buttons["Add Device"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("VersaBraille")
        tapRow("VersaBraille")
        XCTAssertTrue(row(startingWith: "Device 1: VersaBraille").waitForExistence(timeout: 10))
    }

    func testSettingsTextSize() {
        tab("More")
        tapRow("Settings")
        tapRow("Text size")
        tapRow("Accessibility size 3")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10) || app.staticTexts["Accessibility size 3"].exists)
        tab("Browse")
        XCTAssertTrue(row(startingWith: "Notetakers").waitForExistence(timeout: 10))
    }

    // MARK: Accessibility audits

    func testAccessibilityAuditMainScreens() {
        tab("Browse"); audit("Browse")
        tab("Search"); audit("Search")
        tab("Favorites"); audit("Favorites")
        tab("Compare"); audit("Compare empty")
        tab("More"); audit("More")
        tapRow("Settings"); audit("Settings")
        goBack()
        tapRow("About ATGuide"); audit("About")
        goBack()
        tapRow("Privacy Policy"); audit("Privacy Policy")
        tab("Browse")
        tapRow("Trivia"); audit("Trivia")
    }

    func testAccessibilityAuditDetailScreens() {
        openNotetaker("VersaBraille"); audit("Device detail")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'About '")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 10))
        audit("Company detail")
    }
}
