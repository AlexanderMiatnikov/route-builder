import XCTest
@testable import RouteBuilderKit

final class ParsingTests: XCTestCase {
    func testPackagesMax_number_string_null() throws {
        let data = """
        {"items":[
          {"id":"a","name":"A","address":"1","phone":"1","packages_max":5},
          {"id":"b","name":"B","address":"1","phone":"1","packages_max":"7"},
          {"id":"c","name":"C","address":"1","phone":"1","packages_max":null}
        ],"page":1,"page_size":10,"has_more":false}
        """.data(using: .utf8)!
        let page = try StopPageParser.page(from: data)
        XCTAssertEqual(page.items[0].packagesMax, 5)
        XCTAssertEqual(page.items[1].packagesMax, 7)
        XCTAssertNil(page.items[2].packagesMax)
    }

    func testNullItemsIsEmptyList() throws {
        let data = #"{"items":null,"page":1,"page_size":10,"has_more":false}"#.data(using: .utf8)!
        XCTAssertEqual(try StopPageParser.page(from: data).items, [])
    }

    func testSkipsMalformedRow() throws {
        let data = """
        {"items":[null,{"id":"ok","name":"Ok","address":"x","phone":"y"}],
         "page":1,"page_size":10,"has_more":false}
        """.data(using: .utf8)!
        XCTAssertEqual(try StopPageParser.page(from: data).items.map(\.id), ["ok"])
    }

    func testDates_isoZ_isoNoZ_unix() throws {
        let data = """
        {"items":[
          {"id":"a","name":"A","address":"1","phone":"1","last_delivery_at":"2026-09-08T13:46:49.378Z"},
          {"id":"b","name":"B","address":"1","phone":"1","last_delivery_at":"2026-09-08T13:46:49.378"},
          {"id":"c","name":"C","address":"1","phone":"1","last_delivery_at":1694176009}
        ],"page":1,"page_size":10,"has_more":false}
        """.data(using: .utf8)!
        let page = try StopPageParser.page(from: data)
        XCTAssertNotNil(page.items[0].lastDeliveryAt)
        XCTAssertNotNil(page.items[1].lastDeliveryAt)
        XCTAssertNotNil(page.items[2].lastDeliveryAt)
        XCTAssertEqual(page.items[0].lastDeliveryAt, page.items[1].lastDeliveryAt)
        XCTAssertEqual(page.items[2].lastDeliveryAt, Date(timeIntervalSince1970: 1694176009))
    }

    func testPhotoNullUrlDropped() throws {
        let data = """
        {"items":[
          {"id":"p0","url":"https://example.com/a.jpg","tag":"entrance"},
          {"id":"p1","url":null,"tag":"parking"}
        ]}
        """.data(using: .utf8)!
        XCTAssertEqual(try PhotoParser.photos(from: data).map(\.id), ["p0"])
    }

    func testInitials() {
        XCTAssertEqual(Initials.make(from: "Sova Studio Gallery"), "SG")
        XCTAssertEqual(Initials.make(from: "Pilates 9 Studio"), "P9")
        XCTAssertEqual(Initials.make(from: "The Little Zoo"), "LZ")
        XCTAssertEqual(Initials.make(from: "Roma Pizza — Central Bus Station branch"), "RP")
        XCTAssertEqual(Initials.make(from: "24/7 Pharmacy"), "2P")
        XCTAssertEqual(Initials.sectionLetter(name: "24/7 Pharmacy"), "#")
    }

    func testStopGroupingSections() {
        let stops = [
            Stop(id: "1", name: "Sova Studio Gallery", address: "1", phone: "1"),
            Stop(id: "2", name: "24/7 Pharmacy", address: "2", phone: "2"),
            Stop(id: "3", name: "Alpha Bakery", address: "3", phone: "3")
        ]
        let sections = StopGrouping.sections(stops)
        XCTAssertEqual(sections.map(\.letter), ["#", "A", "S"])
        XCTAssertEqual(sections[0].stops.map(\.id), ["2"])
        XCTAssertEqual(sections[1].stops.map(\.id), ["3"])
        XCTAssertEqual(sections[2].stops.map(\.id), ["1"])
    }

    func testClampAndInstructionCap() {
        XCTAssertEqual(PackageCount.clamp(0, max: 5), 1)
        XCTAssertEqual(PackageCount.clamp(99, max: nil), 9)
        XCTAssertEqual(InstructionRules.maxCharacters, 200)
        XCTAssertTrue(InstructionRules.isEmpty("  \n"))
        let long = String(repeating: "a", count: 250)
        XCTAssertEqual(RouteStopPayload(stopID: "x", packages: 0, instructions: long).normalized().instructions.count, 200)
        XCTAssertEqual(RouteStopPayload(stopID: "x", packages: 0, instructions: "hi").normalized().packages, 1)
    }
}
