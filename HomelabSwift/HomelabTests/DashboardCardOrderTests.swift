import XCTest
@testable import Homelab

final class DashboardCardOrderTests: XCTestCase {
    func testDefaultOrderWhenEmpty() {
        let result = DashboardCardID.normalizeOrder([])
        XCTAssertEqual(result, DashboardCardID.allCases)
        XCTAssertEqual(result, [.hero, .docker, .qbittorrent])
    }

    func testPreservesKnownOrderAndAppendsMissing() {
        let result = DashboardCardID.normalizeOrder([.qbittorrent, .docker])
        XCTAssertEqual(result.first, .qbittorrent)
        XCTAssertEqual(result[1], .docker)
        XCTAssertTrue(result.contains(.hero))
        XCTAssertEqual(result.count, DashboardCardID.allCases.count)
    }

    func testDedupesDuplicates() {
        let result = DashboardCardID.normalizeOrder([.docker, .docker, .hero])
        XCTAssertEqual(result.filter { $0 == .docker }.count, 1)
        XCTAssertEqual(result.count, DashboardCardID.allCases.count)
    }

    func testMigratesLegacyMetricCardsToHero() {
        let result = DashboardCardID.normalizeOrder(rawValues: ["cpu", "memory", "docker", "disk"])
        XCTAssertEqual(result.first, .hero)
        XCTAssertEqual(result[1], .docker)
        XCTAssertTrue(result.contains(.qbittorrent))
        XCTAssertEqual(result.count, 3)
        // cpu/memory/disk all map to hero once
        XCTAssertEqual(result.filter { $0 == .hero }.count, 1)
    }

    func testSpansFullWidthOnlyHero() {
        XCTAssertTrue(DashboardCardID.hero.spansFullWidth)
        XCTAssertFalse(DashboardCardID.docker.spansFullWidth)
        XCTAssertFalse(DashboardCardID.qbittorrent.spansFullWidth)
    }
}
