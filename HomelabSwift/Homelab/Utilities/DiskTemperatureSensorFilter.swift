import Foundation

enum DiskTemperatureSensorFilter {
    private static let positiveKeywords = [
        "disk", "hdd", "ssd", "nvme", "drive", "wd", "seagate", "smart"
    ]
    private static let negativeKeywords = [
        "cpu", "core", "gpu", "package", "pch", "acpi", "soc"
    ]

    static func diskSensors(from sensors: [String: Double]) -> [(name: String, celsius: Double)] {
        sensors.compactMap { name, celsius -> (name: String, celsius: Double)? in
            guard celsius > 0 else { return nil }
            let lower = name.lowercased()
            let hitsPositive = positiveKeywords.contains { lower.contains($0) }
            let hitsNegative = negativeKeywords.contains { lower.contains($0) }
            guard hitsPositive, !hitsNegative else { return nil }
            return (name, celsius)
        }
        .sorted { $0.celsius > $1.celsius }
    }
}
