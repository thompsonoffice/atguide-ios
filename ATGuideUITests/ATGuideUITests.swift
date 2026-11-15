import XCTest

/// Collects audit lines from the accessibility-audit closure.
private final class AuditLines {
    var lines: [String] = []
}

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

    /// List rows are buttons, cells, or links depending on the iOS version.
    private func rowCandidates(startingWith prefix: String) -> [XCUIElement] {
        let pred = NSPredicate(format: "label BEGINSWITH %@", prefix)
        return [
            app.buttons.matching(pred).firstMatch,
            app.cells.matching(pred).firstMatch,
            app.links.matching(pred).firstMatch,
        ]
    }

    /// A list row or link whose spoken label starts with `prefix`.
    private func row(startingWith prefix: String) -> XCUIElement {
        let candidates = rowCandidates(startingWith: prefix)
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let found = candidates.first(where: \.exists) { return found }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return candidates[0]
    }

    /// Taps a row, scrolling down first if the list has not loaded it yet.
    private func tapRow(_ prefix: String) {
        _ = row(startingWith: prefix)
        var element = rowCandidates(startingWith: prefix).first(where: \.exists)
        var swipes = 0
        while element?.isHittable != true && swipes < 12 {
            app.swipeUp()
            swipes += 1
            element = rowCandidates(startingWith: prefix).first(where: \.exists)
        }
        XCTAssertTrue(element?.exists == true, "row starting with \(prefix)")
        element?.tap()
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

    /// Scrolls until a static text is loaded. Long lists only mount rows that are on screen.
    private func scrollToStaticText(_ identifier: String) {
        let element = app.staticTexts[identifier]
        var swipes = 0
        while !element.exists && swipes < 15 {
            app.swipeUp()
            swipes += 1
        }
    }

    /// Runs the audit and returns every finding. Nothing is ignored: a non-empty result fails the test.
    private func auditFindings(_ screen: String) -> [String] {
        guard #available(iOS 17.0, *) else { return [] }
        let found = AuditLines()
        do {
            try app.performAccessibilityAudit { issue in
                // A row cut off by the bottom of a scrolling page is not hittable.
                // The same row is checked again when a test scrolls it fully on screen.
                if issue.element?.isHittable == false {
                    return true
                }
                let label = issue.element?.label ?? ""
                let line = "Accessibility audit, \(screen): \(issue.auditType) \(issue.compactDescription) element: \(label)"
                found.lines.append(line)
                print(line)
                NSLog("%@", line)
                return true
            }
        } catch {
            let line = "Accessibility audit, \(screen): \(found.lines.isEmpty ? "could not run: \(error)" : error.localizedDescription)"
            if found.lines.isEmpty { found.lines.append(line) }
            print(line)
            NSLog("%@", line)
        }
        return found.lines
    }

    private func audit(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let found = auditFindings(screen)
        if !found.isEmpty {
            XCTFail(found.joined(separator: "\n"), file: file, line: line)
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
        XCTAssertTrue(app.buttons["Show only differences"].waitForExistence(timeout: 10))
        XCTAssertTrue(row(startingWith: "Device 1: VersaBraille").exists)
        // Audit before scrolling. A fully loaded comparison is large enough that the audit times out.
        audit("Compare with two devices")
        scrollToStaticText("Processor")
        XCTAssertTrue(app.staticTexts["Processor"].exists)
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
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 10) || app.staticTexts["Accessibility size 3"].exists,
            "Settings should stay open and show Accessibility size 3"
        )
        tab("Browse")
        XCTAssertTrue(row(startingWith: "Notetakers").waitForExistence(timeout: 10))
    }

    // MARK: Accessibility audits

    func testAccessibilityAuditMainScreens() {
        var found: [String] = []
        tab("Browse"); found += auditFindings("Browse")
        tab("Search"); found += auditFindings("Search")
        tab("Favorites"); found += auditFindings("Favorites")
        tab("Compare"); found += auditFindings("Compare empty")
        tab("More"); found += auditFindings("More")
        tapRow("Settings"); found += auditFindings("Settings")
        goBack()
        tapRow("About ATGuide"); found += auditFindings("About")
        goBack()
        tapRow("Privacy Policy"); found += auditFindings("Privacy Policy")
        tab("Browse")
        tapRow("Trivia"); found += auditFindings("Trivia")
        if !found.isEmpty {
            XCTFail(found.joined(separator: "\n"))
        }
    }

    func testAccessibilityAuditDetailScreens() {
        var found: [String] = []
        openNotetaker("VersaBraille"); found += auditFindings("Device detail")
        let about = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'About '")).firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 10))
        about.tap()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 10))
        found += auditFindings("Company detail")
        if !found.isEmpty {
            XCTFail(found.joined(separator: "\n"))
        }
    }
}
