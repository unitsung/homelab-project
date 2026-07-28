import Foundation

enum DashboardCardID: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case cpu
    case memory
    case disk
    case diskTemperature
    case docker

    var id: String { rawValue }

    /// Default display order for the home metric grid.
    static var defaultOrder: [DashboardCardID] { Array(allCases) }

    /// Keeps first occurrence of each known id, then appends any missing cases in `defaultOrder`.
    static func normalizeOrder(_ raw: [DashboardCardID]) -> [DashboardCardID] {
        var seen = Set<DashboardCardID>()
        var result: [DashboardCardID] = []
        for id in raw where seen.insert(id).inserted {
            result.append(id)
        }
        for id in defaultOrder where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    static func normalizeOrder(rawValues: [String]) -> [DashboardCardID] {
        normalizeOrder(rawValues.compactMap(DashboardCardID.init(rawValue:)))
    }
}
