import XCTest
#if canImport(ATGuideMac)
@testable import ATGuideMac
#else
@testable import ATGuide
#endif

/// Favorites, recently viewed and compare picks, each against a throwaway UserDefaults suite.
final class UserStateTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ATGuideTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFavoritesToggleAndPersist() {
        let favorites = FavoritesStore(defaults: defaults)
        favorites.toggle("dev:bns")
        favorites.toggle("co:blazie")
        XCTAssertTrue(favorites.contains("dev:bns"))
        favorites.toggle("dev:bns")
        XCTAssertFalse(favorites.contains("dev:bns"))
        XCTAssertEqual(FavoritesStore(defaults: defaults).keys, ["co:blazie"], "saved across launches")
        favorites.removeAll()
        XCTAssertTrue(FavoritesStore(defaults: defaults).keys.isEmpty)
    }

    func testRecentsNewestFirstWithoutDuplicates() {
        let recents = RecentsStore(defaults: defaults)
        recents.record("dev:a")
        recents.record("dev:b")
        recents.record("dev:a")
        XCTAssertEqual(recents.keys, ["dev:a", "dev:b"])
        XCTAssertEqual(RecentsStore(defaults: defaults).keys, ["dev:a", "dev:b"])
    }

    func testRecentsAreCapped() {
        let recents = RecentsStore(defaults: defaults)
        for i in 0..<(RecentsStore.limit + 10) { recents.record("dev:\(i)") }
        XCTAssertEqual(recents.keys.count, RecentsStore.limit)
        XCTAssertEqual(recents.keys.first, "dev:\(RecentsStore.limit + 9)")
    }

    func testCompareHoldsAtMostThree() {
        let compare = CompareStore(defaults: defaults)
        XCTAssertTrue(compare.add("a"))
        XCTAssertFalse(compare.add("a"), "no duplicates")
        XCTAssertTrue(compare.add("b"))
        XCTAssertTrue(compare.add("c"))
        XCTAssertTrue(compare.isFull)
        XCTAssertFalse(compare.add("d"))
        XCTAssertEqual(compare.ids, ["a", "b", "c"])
        compare.remove("b")
        XCTAssertEqual(CompareStore(defaults: defaults).ids, ["a", "c"])
        compare.removeAll()
        XCTAssertTrue(compare.ids.isEmpty)
    }

    func testTextSizeOptions() {
        XCTAssertNil(TextSizeOption.system.dynamicTypeSize)
        XCTAssertEqual(TextSizeOption.accessibility5.dynamicTypeSize, .accessibility5)
        XCTAssertEqual(TextSizeOption.allCases.count, 13)
    }

    func testPrivacyPolicyHasNoPlaceholders() {
        let all = PrivacyPolicy.paragraphs.map { $0.heading + $0.body }.joined()
        XCTAssertFalse(all.contains("["))
        XCTAssertTrue(all.contains("does not collect"))
    }
}
