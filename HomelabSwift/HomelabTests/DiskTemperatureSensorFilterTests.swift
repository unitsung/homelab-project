import XCTest
@testable import Homelab

final class DiskTemperatureSensorFilterTests: XCTestCase {
    func testKeepsDiskLikeNames() {
        let input: [String: Double] = [
            "nvme0n1": 42,
            "SSD": 38,
            "cpu_package": 70,
            "Core 0": 65,
            "hdd_bay1": 33
        ]
        let names = DiskTemperatureSensorFilter.diskSensors(from: input).map(\.name)
        XCTAssertTrue(names.contains("nvme0n1"))
        XCTAssertTrue(names.contains("SSD"))
        XCTAssertTrue(names.contains("hdd_bay1"))
        XCTAssertFalse(names.contains("cpu_package"))
        XCTAssertFalse(names.contains("Core 0"))
    }

    func testDropsNonPositiveTemps() {
        let input: [String: Double] = ["ssd0": 0, "nvme1": -1, "disk1": 40]
        let result = DiskTemperatureSensorFilter.diskSensors(from: input)
        XCTAssertEqual(result.map(\.name), ["disk1"])
    }

    func testSortsHottestFirst() {
        let input: [String: Double] = ["ssd_a": 30, "ssd_b": 50]
        let result = DiskTemperatureSensorFilter.diskSensors(from: input)
        XCTAssertEqual(result.map(\.celsius), [50, 30])
    }
}
