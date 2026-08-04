import Foundation

/// Home dashboard cards that can be reordered (matches what `HomeView` actually renders).
enum DashboardCardID: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case hero
    case docker
    case qbittorrent

    var id: String { rawValue }

    /// Full-width hero vs half-width grid tiles.
    var spansFullWidth: Bool {
        switch self {
        case .hero: return true
        case .docker, .qbittorrent: return false
        }
    }

    /// Default display order for the home metric/overview strip.
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

    /// Accepts current ids plus legacy metric keys from the pre-Hero redesign.
    static func normalizeOrder(rawValues: [String]) -> [DashboardCardID] {
        let mapped = rawValues.compactMap(Self.init(migrating:))
        return normalizeOrder(mapped)
    }

    /// Map stored raw values → current cases. Old cpu/memory/disk/temp collapse to `.hero`.
    init?(migrating rawValue: String) {
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let modern = DashboardCardID(rawValue: key) {
            self = modern
            return
        }
        switch key {
        case "cpu", "memory", "disk", "disktemperature", "disk_temperature", "system", "overview":
            self = .hero
        case "qbit", "qbittorrent":
            self = .qbittorrent
        default:
            return nil
        }
    }
}
