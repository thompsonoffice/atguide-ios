import XCTest
#if canImport(ATGuideMac)
@testable import ATGuideMac
#else
@testable import ATGuide
#endif

/// Checks the bundled ATGuide 2.0 data and the store's lookups, search, comparison and export.
final class ATGuideDataTests: XCTestCase {
    private static let shared: ATGuideStore = {
        let bundle = Bundle(for: FavoritesStore.self)
        return try! ATGuideStore.loadBundled(bundle: bundle)
    }()
    private var store: ATGuideStore { Self.shared }

    func testBundledDataLoadsWithATGuide20Counts() {
        XCTAssertEqual(store.data.edition, "ATGuide 2.0")
        XCTAssertEqual(store.devices.count, 437)
        XCTAssertEqual(store.companies.count, 104)
        XCTAssertEqual(store.osHistories.count, 28)
        XCTAssertEqual(store.data.trivia.count, 102)
    }

    func testIDsAreUnique() {
        XCTAssertEqual(Set(store.devices.map(\.id)).count, store.devices.count)
        XCTAssertEqual(Set(store.companies.map(\.id)).count, store.companies.count)
        XCTAssertEqual(Set(store.osHistories.map(\.id)).count, store.osHistories.count)
    }

    func testEveryReferenceResolves() {
        for d in store.devices {
            XCTAssertNotNil(store.company(d.company), "\(d.id) has unknown company \(d.company)")
            for ref in (d.predecessors ?? []) + (d.successors ?? []) + (d.voices ?? []) {
                XCTAssertNotNil(store.device(ref), "\(d.id) links to missing \(ref)")
            }
            XCTAssertFalse(d.name.isEmpty)
            XCTAssertFalse((d.sources ?? []).isEmpty, "\(d.id) has no sources")
        }
        for o in store.osHistories { XCTAssertNotNil(store.company(o.company)) }
        for t in store.data.trivia { if let id = t.device { XCTAssertNotNil(store.device(id)) } }
    }

    func testEveryDeviceIsInAListedCategory() {
        let groups = store.categoryGroups
        XCTAssertEqual(groups.reduce(0) { $0 + $1.devices.count }, store.devices.count)
        XCTAssertTrue(store.categories.contains("Braille Displays"))
        XCTAssertTrue(store.categories.contains("Echo Displays"))
        XCTAssertEqual(store.categories.first, "Notetakers")
    }

    func testCategoryListIsOldestFirst() {
        let notetakers = store.devices(inCategory: "Notetakers")
        XCTAssertEqual(notetakers.map(\.sortYear), notetakers.map(\.sortYear).sorted())
        XCTAssertEqual(notetakers.first?.name, "VersaBraille")
    }

    func testCompanyCatalogMatchesProductCount() {
        for c in store.companies {
            XCTAssertEqual(store.catalog(of: c.id).reduce(0) { $0 + $1.devices.count }, store.productCount(of: c.id))
        }
    }

    // MARK: Search

    func testSearchFindsByName() {
        let results = store.searchDevices("BrailleNote")
        XCTAssertGreaterThanOrEqual(results.count, 9)
        XCTAssertTrue(results.prefix(9).allSatisfy { $0.name.hasPrefix("BrailleNote") }, "name matches rank first")
    }

    func testSearchIsCaseAndAccentInsensitive() {
        XCTAssertEqual(store.searchDevices("braillenote").map(\.id), store.searchDevices("BRAILLENOTE").map(\.id))
        XCTAssertEqual(ATGuideStore.fold("André DECtalk"), "andre dectalk")
    }

    func testSearchRequiresEveryWord() {
        let both = store.searchDevices("BrailleNote Touch")
        XCTAssertFalse(both.isEmpty)
        XCTAssertEqual(both.first?.id, "bntouch", "exact name match ranks first")
        XCTAssertTrue(both.allSatisfy { d in
            let hay = ATGuideStore.fold(TextExporter(store: store).text(for: d))
            return hay.contains("braillenote") && hay.contains("touch")
        })
        XCTAssertTrue(store.searchDevices("zzzz-not-a-device qqqq").isEmpty)
    }

    func testSearchCoversFullText() {
        // "Gissoni" appears only in the Braille 'n Speak history text, not its name.
        XCTAssertTrue(store.searchDevices("Gissoni").contains { $0.id == "bns" })
    }

    func testSearchCategoryFilter() {
        let results = store.searchDevices("", category: "TTS Voices")
        XCTAssertEqual(results.count, store.devices(inCategory: "TTS Voices").count)
        XCTAssertTrue(results.allSatisfy { $0.category == "TTS Voices" })
    }

    func testCompanyAndOSSearch() {
        XCTAssertFalse(store.searchCompanies("HumanWare").isEmpty)
        XCTAssertTrue(store.searchCompanies("   ").isEmpty)
        XCTAssertTrue(store.searchOS("KeySoft").contains { $0.name == "KeySoft" })
        XCTAssertTrue(store.searchOS("NVDA").contains { $0.name == "NVDA versions" })
    }

    // MARK: Comparison

    func testComparisonRowsHaveOneValuePerDevice() throws {
        let a = try XCTUnwrap(store.device("bntouch"))
        let b = try XCTUnwrap(store.device("bnclassic"))
        let c = try XCTUnwrap(store.device("bns"))
        let rows = store.comparisonRows(for: [a, b, c])
        XCTAssertEqual(rows.first?.label, "Company")
        XCTAssertTrue(rows.contains { $0.label == "Processor" })
        XCTAssertTrue(rows.allSatisfy { $0.values.count == 3 })
        XCTAssertEqual(Set(rows.map(\.label)).count, rows.count, "labels are unique")
        XCTAssertEqual(rows.first { $0.label == "Category" }?.differs, false)
        XCTAssertEqual(rows.first { $0.label == "Released" }?.differs, true)
    }

    func testComparisonOfVoiceAndHardwareUsesNotDocumented() throws {
        let voice = try XCTUnwrap(store.devices(inCategory: "TTS Voices").first)
        let hw = try XCTUnwrap(store.device("bns"))
        let rows = store.comparisonRows(for: [hw, voice])
        let processor = try XCTUnwrap(rows.first { $0.label == "Processor" })
        XCTAssertEqual(processor.values[1], notDocumented)
    }

    // MARK: Export

    func testTextExportHasEverySection() throws {
        let d = try XCTUnwrap(store.device("bns"))
        let text = TextExporter(store: store).text(for: d)
        for heading in ["Overview:", "Specs:", "Physical Description:", "Features:", "History:", "Ports:",
                        "Operating System:", "System Requirements:", "Sources:"] {
            XCTAssertTrue(text.contains(heading), "missing \(heading)")
        }
        XCTAssertTrue(text.hasPrefix("Braille 'n Speak (original)"))
    }

    func testFileNames() {
        XCTAssertEqual(TextExporter.fileName("Braille 'n Speak (original)"), "Braille 'n Speak (original).txt")
        XCTAssertEqual(TextExporter.fileName("A/B: C?"), "A-B C.txt")
        XCTAssertEqual(TextExporter.fileName(""), "Untitled.txt")
    }

    func testSavedKeyParsingAndTitles() {
        XCTAssertEqual(FavoriteKey.parse("dev:bns")?.id, "bns")
        XCTAssertNil(FavoriteKey.parse("bogus"))
        XCTAssertEqual(store.title(forKey: "dev:bns"), "Braille 'n Speak (original)")
        XCTAssertNil(store.title(forKey: "dev:does-not-exist"))
    }
}
