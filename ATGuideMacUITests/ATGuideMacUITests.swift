import XCTest

/// Smoke tests for the Mac sidebar and a few main screens.
/// These do not replace testing with VoiceOver on a real Mac.
final class ATGuideMacUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ATGuideUITesting"]
        app.launch()
    }

    func testSidebarAndBrowseExist() {
        let browse = app.buttons["Browse"]
        let alt = app.staticTexts["Browse"]
        XCTAssertTrue(
            browse.waitForExistence(timeout: 10) || alt.waitForExistence(timeout: 10),
            "The Browse sidebar item should appear at launch."
        )
        XCTAssertTrue(
            app.staticTexts["Categories"].waitForExistence(timeout: 8)
            || app.staticTexts["ATGuide"].waitForExistence(timeout: 2),
            "The Browse list should show Categories or the ATGuide title."
        )
    }

    func testOpenNotetakersAndDevice() {
        let notetakers = app.staticTexts["Notetakers"]
        XCTAssertTrue(notetakers.waitForExistence(timeout: 10))
        notetakers.click()
        let device = app.staticTexts["BrailleNote Touch"]
        XCTAssertTrue(device.waitForExistence(timeout: 8), "Notetakers should list BrailleNote Touch.")
        device.click()
        XCTAssertTrue(
            app.staticTexts["Overview"].waitForExistence(timeout: 8)
            || app.staticTexts["BrailleNote Touch"].waitForExistence(timeout: 2),
            "The device page should open."
        )
    }

    func testSearchFindsBrailleNoteTouch() {
        let search = app.buttons["Search"]
        let alt = app.staticTexts["Search"]
        if search.waitForExistence(timeout: 6) {
            search.click()
        } else {
            XCTAssertTrue(alt.waitForExistence(timeout: 6))
            alt.click()
        }
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "Search should show a search field.")
        field.click()
        field.typeText("BrailleNote Touch")
        XCTAssertTrue(
            app.staticTexts["BrailleNote Touch"].waitForExistence(timeout: 8),
            "Search should list BrailleNote Touch."
        )
    }
}
