import XCTest
@testable import Homelab

final class DashboardCardOrderTests: XCTestCase {
    func testDefaultOrderWhenEmpty() {
        let result = DashboardCardID.normalizeOrder([])
        XCTAssertEqual(result, DashboardCardID.allCases)
    }

    func testPreservesKnownOrderAndAppendsMissing() {
        let result = DashboardCardID.normalizeOrder([.docker, .cpu])
        XCTAssertEqual(result.first, .docker)
        XCTAssertEqual(result[1], .cpu)
        XCTAssertTrue(result.contains(.memory))
        XCTAssertTrue(result.contains(.disk))
        XCTAssertTrue(result.contains(.diskTemperature))
        XCTAssertEqual(result.count, DashboardCardID.allCases.count)
    }

    func testDedupesDuplicates() {
        let result = DashboardCardID.normalizeOrder([.cpu, .cpu, .memory])
        XCTAssertEqual(result.filter { $0 == .cpu }.count, 1)
        XCTAssertEqual(result.count, DashboardCardID.allCases.count)
    }
}
