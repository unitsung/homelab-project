import XCTest
@testable import Homelab

@MainActor
final class DashboardSystemStoreTests: XCTestCase {

    /// Regression: incomplete disk fields must not recurse between total/percent
    /// (previously stack-overflowed as EXC_BAD_ACCESS in DiskMonitorCard.task).
    func testFilesystemMetricsDoNotRecurseWithPartialDiskFields() {
        let store = DashboardSystemStore()
        store.systemInfo = BeszelSystemInfo(
            cpu: 1,
            mp: 50,
            m: 8,
            mt: 16,
            dp: nil,
            d: nil,
            du: 100,
            dt: nil,
            ns: nil,
            nr: nil,
            u: nil,
            cm: nil,
            os: nil,
            k: nil,
            h: "test",
            t: nil,
            c: nil,
            efs: nil
        )
        store.latestStats = nil

        // Accessing these used to infinite-recurse when total and percent
        // were both missing (only used was present). Completing without
        // stack overflow is the primary assertion.
        XCTAssertEqual(store.rootDiskUsedGB, 100, accuracy: 0.001)
        XCTAssertEqual(store.rootDiskTotalGB, 0, accuracy: 0.001)
        XCTAssertEqual(store.rootDiskPercent, 0, accuracy: 0.001)
        // Root is only listed when total or percent is known.
        _ = store.filesystems
    }

    func testRootDiskDerivesTotalFromUsedAndPercent() {
        let store = DashboardSystemStore()
        store.systemInfo = BeszelSystemInfo(
            cpu: nil,
            mp: nil,
            m: nil,
            mt: nil,
            dp: 50,
            d: nil,
            du: 100,
            dt: nil,
            ns: nil,
            nr: nil,
            u: nil,
            cm: nil,
            os: nil,
            k: nil,
            h: nil,
            t: nil,
            c: nil,
            efs: nil
        )

        XCTAssertEqual(store.rootDiskUsedGB, 100, accuracy: 0.001)
        XCTAssertEqual(store.rootDiskTotalGB, 200, accuracy: 0.001)
        XCTAssertEqual(store.rootDiskPercent, 50, accuracy: 0.001)
    }

    func testRootDiskPrefersSystemStatsFields() throws {
        let statsJSON = """
        {
            "cpu": 10,
            "dp": 40,
            "d": 500,
            "du": 200,
            "dt": 500
        }
        """.data(using: .utf8)!
        let stats = try JSONDecoder().decode(BeszelRecordStats.self, from: statsJSON)

        let store = DashboardSystemStore()
        store.latestStats = stats

        XCTAssertEqual(store.rootDiskUsedGB, 200, accuracy: 0.001)
        XCTAssertEqual(store.rootDiskTotalGB, 500, accuracy: 0.001)
        XCTAssertEqual(store.rootDiskPercent, 40, accuracy: 0.001)
    }
}
