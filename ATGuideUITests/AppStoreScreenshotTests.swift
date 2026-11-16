import XCTest

/// Captures 6.9-inch App Store screenshots as XCTest attachments (and PNG files
/// when SCREENSHOT_DIR is set). Set APP_STORE_SCREENSHOTS=0 to skip.
/// Does not change app behavior.
final class AppStoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let env = ProcessInfo.processInfo.environment
        // On this branch the tests run during regular CI so screenshots land in the
        // xcresult artifact. Set APP_STORE_SCREENSHOTS=0 to skip.
        try XCTSkipIf(
            env["APP_STORE_SCREENSHOTS"] == "0",
            "Screenshot tests skipped because APP_STORE_SCREENSHOTS=0"
        )
        continueAfterFailure = false
        let path = env["SCREENSHOT_DIR"] ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("atspotlight-screenshots", isDirectory: true).path
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments = [
            "-ATGuideUITesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-AppleInterfaceStyle", "Light",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Browse"].waitForExistence(timeout: 15), "Browse tab")
        settle()
    }

    func testCaptureAppStoreScreenshots() throws {
        try capture("01-browse")

        tab("Browse")
        tapRow("Notetakers")
        XCTAssertTrue(app.navigationBars["Notetakers"].waitForExistence(timeout: 10))
        settle()
        try capture("02-notetakers")

        tapRow("BrailleNote Touch,")
        XCTAssertTrue(app.staticTexts["Overview"].waitForExistence(timeout: 10))
        settle()
        try capture("03-device-detail")

        tab("Search")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("BrailleNote Touch")
        XCTAssertTrue(app.staticTexts["resultCount"].waitForExistence(timeout: 10))
        dismissKeyboard()
        settle()
        try capture("04-search")

        // Add devices from the Compare tab so this does not depend on Browse
        // still being on a category or detail page after the earlier shots.
        tab("Compare")
        addDeviceToCompare("VersaBraille,")
        addDeviceToCompare("BrailleNote Touch,")
        XCTAssertTrue(app.buttons["Show only differences"].waitForExistence(timeout: 10))
        settle()
        try capture("05-compare")

        tab("More")
        XCTAssertTrue(app.buttons["About ATGuide"].waitForExistence(timeout: 10) || app.staticTexts["About ATGuide"].waitForExistence(timeout: 2))
        settle()
        try capture("06-more")

        let files = try FileManager.default.contentsOfDirectory(atPath: outputDirectory.path)
            .filter { $0.hasSuffix(".png") }
            .sorted()
        XCTAssertEqual(files.count, 6, "Expected 6 screenshots, found \(files)")
    }

    // MARK: - Capture

    private func capture(_ name: String) throws {
        settle()
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = outputDirectory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: url)
        let size = pngSize(at: url)
        let line = "Wrote \(url.path) \(size.map { "\($0.width)x\($0.height)" } ?? "unknown-size")"
        print(line)
        NSLog("%@", line)
        if let size {
            let accepted = [
                (1320, 2868),
                (1290, 2796),
            ]
            XCTAssertTrue(
                accepted.contains(where: { $0.0 == size.width && $0.1 == size.height }),
                "\(name) is \(size.width)x\(size.height); App Store 6.9-inch needs 1320x2868 or 1290x2796"
            )
        } else {
            XCTFail("Could not read PNG dimensions for \(name)")
        }
    }

    private func pngSize(at url: URL) -> (width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: url), data.count >= 24 else { return nil }
        let header = [UInt8](data.subdata(in: 0..<16))
        // PNG signature + IHDR length/type should precede 8-byte width/height
        guard header.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else { return nil }
        let dim = data.subdata(in: 16..<24)
        let width = dim.subdata(in: 0..<4).withUnsafeBytes { Int($0.load(as: UInt32.self).bigEndian) }
        let height = dim.subdata(in: 4..<8).withUnsafeBytes { Int($0.load(as: UInt32.self).bigEndian) }
        return (width, height)
    }

    // MARK: - Navigation helpers (same patterns as ATGuideUITests)

    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "tab \(name)")
        button.tap()
    }

    private func rowCandidates(startingWith prefix: String) -> [XCUIElement] {
        let pred = NSPredicate(format: "label BEGINSWITH %@", prefix)
        return [
            app.buttons.matching(pred).firstMatch,
            app.cells.matching(pred).firstMatch,
            app.links.matching(pred).firstMatch,
        ]
    }

    private func row(startingWith prefix: String) -> XCUIElement {
        let candidates = rowCandidates(startingWith: prefix)
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let found = candidates.first(where: \.exists) { return found }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return candidates[0]
    }

    private func tapRow(_ prefix: String) {
        _ = row(startingWith: prefix)
        var element = rowCandidates(startingWith: prefix).first(where: \.exists)
        var swipes = 0
        while element?.isHittable != true && swipes < 16 {
            if swipes % 2 == 0 { app.swipeUp() } else { app.swipeDown() }
            swipes += 1
            element = rowCandidates(startingWith: prefix).first(where: \.exists)
        }
        XCTAssertTrue(element?.exists == true, "row starting with \(prefix)")
        element?.tap()
    }

    private func addDeviceToCompare(_ prefix: String) {
        let add = app.buttons["Add Device"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add Device")
        add.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "compare search field")
        field.tap()
        field.typeText(String(prefix.trimmingCharacters(in: CharacterSet(charactersIn: ","))))
        tapRow(prefix)
        // Back on the compare list, the first device row should exist.
        settle()
    }

    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func dismissKeyboard() {
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
            return
        }
        if app.keyboards.buttons["search"].exists {
            app.keyboards.buttons["search"].tap()
            return
        }
        if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
            return
        }
        app.swipeDown()
    }

    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }
}
