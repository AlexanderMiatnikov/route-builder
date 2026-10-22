import XCTest
@testable import RouteBuilderKit

final class StopSearchTests: XCTestCase {
    private let search = StopSearch()
    private let sova = Stop(id: "stp_1002", name: "Sova Studio Gallery", address: "42 King St, Northbridge", phone: "02079460477")
    private let cafe = Stop(id: "stp_1001", name: "North Cafe", address: "12 North Rd, Northbridge", phone: "+44-20-7946-0188")
    private let taylor = Stop(id: "stp_1021", name: "Taylor & Sons Distribution", address: "18 Fiber Rd, Southgate", phone: "020-7946-0606")

    func testLowercaseQueryMatchesCapitalizedName() {
        XCTAssertTrue(search.matches(sova, query: "sova"))
        XCTAssertTrue(search.matches(cafe, query: "north cafe"))
        XCTAssertTrue(search.matches(cafe, query: "  NORTH CAFE "))
        XCTAssertFalse(search.matches(sova, query: "north cafe"))
    }

    func testMatchesAddressAndPunctuation() {
        XCTAssertTrue(search.matches(sova, query: "king st"))
        XCTAssertTrue(search.matches(taylor, query: "taylor & s"))
    }

    func testPhoneNeedsThreeDigits() {
        XCTAssertTrue(search.matches(cafe, query: "7946 0188"))
        XCTAssertFalse(search.matches(cafe, query: "01"))
    }

    func testBlankQueryMatchesNothing() {
        XCTAssertFalse(search.matches(sova, query: "   "))
    }

    func testCombineKeepsServerOrderAndDedupes() {
        let merged = search.combine(server: [cafe], local: [sova, cafe])
        XCTAssertEqual(merged.map(\.id), ["stp_1001", "stp_1002"])
    }

    func testServerNullItemsStillYieldLocalMatch() async throws {
        // Mock answers `{"items":null}` for "sova" (case-sensitive includes).
        let page = try StopPageParser().page(
            from: Data(#"{"items":null,"page":1,"page_size":50,"has_more":false}"#.utf8)
        )
        let results = search.combine(
            server: page.items,
            local: search.filter([sova, cafe], query: "sova")
        )
        XCTAssertEqual(results.map(\.name), ["Sova Studio Gallery"])
    }
}
