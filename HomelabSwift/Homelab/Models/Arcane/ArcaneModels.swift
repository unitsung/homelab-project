import Foundation

// MARK: - API wrappers (Arcane wraps most REST payloads as { success, data })

struct ArcaneAPIResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let success: Bool?
    let data: T
}

/// Matches OpenAPI `ContainerPaginatedResponse` / other paginated wrappers.
/// `data` is typed as `array | null` in Arcane 2.5 OpenAPI.
struct ArcanePaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let success: Bool?
    let data: [T]
    let counts: ArcaneStatusCounts?
    let pagination: ArcanePagination?

    enum CodingKeys: String, CodingKey {
        case success, data, counts, pagination
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success)
        // OpenAPI: "type": ["array", "null"]
        data = (try c.decodeIfPresent([T].self, forKey: .data)) ?? []
        counts = try c.decodeIfPresent(ArcaneStatusCounts.self, forKey: .counts)
        pagination = try c.decodeIfPresent(ArcanePagination.self, forKey: .pagination)
    }

    init(success: Bool?, data: [T], counts: ArcaneStatusCounts?, pagination: ArcanePagination?) {
        self.success = success
        self.data = data
        self.counts = counts
        self.pagination = pagination
    }
}

struct ArcanePagination: Codable, Sendable {
    let totalPages: Int?
    let totalItems: Int?
    let currentPage: Int?
    let itemsPerPage: Int?
    let grandTotalItems: Int?
}

struct ArcaneStatusCounts: Codable, Sendable, Hashable {
    let runningContainers: Int?
    let stoppedContainers: Int?
    let totalContainers: Int?

    var running: Int { runningContainers ?? 0 }
    var stopped: Int { stoppedContainers ?? 0 }
    var total: Int { totalContainers ?? 0 }
}

// MARK: - Auth

struct ArcaneLoginResponse: Codable, Sendable {
    let token: String
    let refreshToken: String?
    let expiresAt: String?
}

// MARK: - Environment

struct ArcaneEnvironment: Identifiable, Codable, Hashable, Sendable {
    static let localId = "0"

    let id: String
    let name: String?
    let apiUrl: String?
    let status: String?
    let enabled: Bool?
    let isEdge: Bool?
    let lastSeen: String?

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        if id == Self.localId { return "Local Docker" }
        return id
    }

    var isOnline: Bool {
        let normalized = (status ?? "").lowercased()
        if normalized == "online" || normalized == "connected" || normalized == "healthy" {
            return true
        }
        if id == Self.localId { return enabled ?? true }
        return enabled ?? false
    }
}

// MARK: - Update info

struct ArcaneImageUpdateInfo: Codable, Hashable, Sendable {
    let hasUpdate: Bool?
    let updateType: String?
    let currentVersion: String?
    let latestVersion: String?
    let currentDigest: String?
    let latestDigest: String?
    let error: String?

    /// OpenAPI `ImageUpdateInfo.hasUpdate` (boolean). Digests are informational only.
    var available: Bool { hasUpdate == true }

    enum CodingKeys: String, CodingKey {
        case hasUpdate, updateType, currentVersion, latestVersion
        case currentDigest, latestDigest, error
        // Tolerate alternate casings from older proxies / intermediate layers.
        case has_update
        case update_available
        case updateAvailable
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasUpdate = Self.decodeFlexibleBool(c, keys: [.hasUpdate, .has_update, .updateAvailable, .update_available])
        updateType = try c.decodeIfPresent(String.self, forKey: .updateType)
        currentVersion = try c.decodeIfPresent(String.self, forKey: .currentVersion)
        latestVersion = try c.decodeIfPresent(String.self, forKey: .latestVersion)
        currentDigest = try c.decodeIfPresent(String.self, forKey: .currentDigest)
        latestDigest = try c.decodeIfPresent(String.self, forKey: .latestDigest)
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(hasUpdate, forKey: .hasUpdate)
        try c.encodeIfPresent(updateType, forKey: .updateType)
        try c.encodeIfPresent(currentVersion, forKey: .currentVersion)
        try c.encodeIfPresent(latestVersion, forKey: .latestVersion)
        try c.encodeIfPresent(currentDigest, forKey: .currentDigest)
        try c.encodeIfPresent(latestDigest, forKey: .latestDigest)
        try c.encodeIfPresent(error, forKey: .error)
    }

    private static func decodeFlexibleBool(
        _ c: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Bool? {
        for key in keys {
            if let b = try? c.decodeIfPresent(Bool.self, forKey: key) { return b }
            if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i != 0 }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                switch s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1", "yes": return true
                case "false", "0", "no": return false
                default: break
                }
            }
        }
        return nil
    }
}

struct ArcaneImageUpdateSummary: Codable, Sendable {
    let totalImages: Int?
    let imagesWithUpdates: Int?
    let digestUpdates: Int?
    let errorsCount: Int?
}

// MARK: - Image usage / prune (OpenAPI: ImageUsageCounts, ImagePruneReport, …)

/// OpenAPI `ImageUsageCounts`
struct ArcaneImageUsageCounts: Codable, Sendable, Hashable {
    let imagesInuse: Int?
    let imagesUnused: Int?
    let totalImages: Int?
    let totalImageSize: Int64?

    var inUse: Int { imagesInuse ?? 0 }
    var unused: Int { imagesUnused ?? 0 }
    var total: Int { totalImages ?? 0 }
    var totalSize: Int64 { totalImageSize ?? 0 }
}

/// OpenAPI `ImagePruneReport`
struct ArcaneImagePruneReport: Codable, Sendable, Hashable {
    let imagesDeleted: [String]?
    let spaceReclaimed: Int64?

    var deletedCount: Int { imagesDeleted?.count ?? 0 }
    var reclaimed: Int64 { spaceReclaimed ?? 0 }

    var userFacingSummary: String {
        let bytes = Formatters.formatBytes(Double(reclaimed))
        if deletedCount > 0 {
            return "Pruned \(deletedCount) image(s), reclaimed \(bytes)"
        }
        return "No unused images · \(bytes) reclaimed"
    }
}

/// OpenAPI `VolumePruneReportData`
struct ArcaneVolumePruneReport: Codable, Sendable, Hashable {
    let volumesDeleted: [String]?
    let spaceReclaimed: Int64?
    let activityId: String?

    var deletedCount: Int { volumesDeleted?.count ?? 0 }
    var reclaimed: Int64 { spaceReclaimed ?? 0 }

    var userFacingSummary: String {
        let bytes = Formatters.formatBytes(Double(reclaimed))
        return "Pruned \(deletedCount) volume(s), reclaimed \(bytes)"
    }
}

/// OpenAPI `NetworkPruneReport`
struct ArcaneNetworkPruneReport: Codable, Sendable, Hashable {
    let networksDeleted: [String]?
    let spaceReclaimed: Int64?
    let activityId: String?

    var deletedCount: Int { networksDeleted?.count ?? 0 }

    var userFacingSummary: String {
        "Pruned \(deletedCount) network(s)"
    }
}

/// OpenAPI `SystemPruneAllResult`
struct ArcaneSystemPruneResult: Codable, Sendable, Hashable {
    let success: Bool?
    let spaceReclaimed: Int64?
    let imagesDeleted: [String]?
    let volumesDeleted: [String]?
    let networksDeleted: [String]?
    let containersPruned: [String]?
    let imageSpaceReclaimed: Int64?
    let volumeSpaceReclaimed: Int64?
    let containerSpaceReclaimed: Int64?
    let buildCacheSpaceReclaimed: Int64?
    let activityId: String?
    let errors: [String]?

    var reclaimed: Int64 { spaceReclaimed ?? 0 }

    var userFacingSummary: String {
        let bytes = Formatters.formatBytes(Double(reclaimed))
        let parts = [
            (imagesDeleted?.count ?? 0, "img"),
            (volumesDeleted?.count ?? 0, "vol"),
            (networksDeleted?.count ?? 0, "net"),
            (containersPruned?.count ?? 0, "ctr")
        ].filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }
        if parts.isEmpty {
            return "System prune · reclaimed \(bytes)"
        }
        return "System prune \(parts.joined(separator: ", ")) · \(bytes)"
    }
}

// MARK: - Images (for update matching)

struct ArcaneImageUsedBy: Codable, Hashable, Sendable {
    let type: String?
    let name: String?
    let id: String?
}

struct ArcaneImageSummary: Identifiable, Decodable, Hashable, Sendable {
    let id: String
    let repoTags: [String]?
    let repoDigests: [String]?
    let created: Int64?
    let size: Int64?
    let inUse: Bool?
    let usedBy: [ArcaneImageUsedBy]?
    let repo: String?
    let tag: String?
    let updateInfo: ArcaneImageUpdateInfo?

    var hasUpdate: Bool { updateInfo?.available == true }

    var primaryTag: String {
        if let repoTags, let first = repoTags.first, !first.isEmpty { return first }
        if let repo, let tag {
            return "\(repo):\(tag)"
        }
        return String(id.prefix(16))
    }

    /// Container IDs / names referenced by this image.
    var usedContainerIds: [String] {
        (usedBy ?? []).compactMap { entry in
            let t = (entry.type ?? "container").lowercased()
            guard t.contains("container") || t.isEmpty else { return nil }
            return entry.id
        }
    }

    var usedContainerNames: [String] {
        (usedBy ?? []).compactMap { entry in
            let t = (entry.type ?? "container").lowercased()
            guard t.contains("container") || t.isEmpty else { return nil }
            return entry.name?.replacingOccurrences(of: "^/", with: "", options: .regularExpression)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Some payloads use "Id" from raw Docker — tolerate both.
        if let id = try c.decodeIfPresent(String.self, forKey: .id), !id.isEmpty {
            self.id = id
        } else if let id = try c.decodeIfPresent(String.self, forKey: .Id), !id.isEmpty {
            self.id = id
        } else {
            self.id = UUID().uuidString
        }
        repoTags = try c.decodeIfPresent([String].self, forKey: .repoTags)
        repoDigests = try c.decodeIfPresent([String].self, forKey: .repoDigests)
        created = try c.decodeIfPresent(Int64.self, forKey: .created)
        size = try c.decodeIfPresent(Int64.self, forKey: .size)
        inUse = try c.decodeIfPresent(Bool.self, forKey: .inUse)
        usedBy = try c.decodeIfPresent([ArcaneImageUsedBy].self, forKey: .usedBy)
        repo = try c.decodeIfPresent(String.self, forKey: .repo)
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
        updateInfo = try? c.decodeIfPresent(ArcaneImageUpdateInfo.self, forKey: .updateInfo)
    }

    enum CodingKeys: String, CodingKey {
        case id, Id, repoTags, repoDigests, created, size, inUse, usedBy, repo, tag, updateInfo
    }
}

/// Optional live stats payload (varies by Arcane version).
struct ArcaneContainerStats: Decodable, Sendable, Hashable {
    let cpuPercent: Double?
    let memoryUsage: Int64?
    let memoryLimit: Int64?
    let netInput: Int64?
    let netOutput: Int64?
    let blockRead: Int64?
    let blockWrite: Int64?

    enum CodingKeys: String, CodingKey {
        case cpuPercent = "CPUPerc"
        case cpuPercentAlt = "cpu_percent"
        case memoryUsage = "MemUsage"
        case memoryUsageAlt = "memory_usage"
        case memoryLimit = "MemLimit"
        case memoryLimitAlt = "memory_limit"
        case netInput = "NetInput"
        case netOutput = "NetOutput"
        case blockRead = "BlockRead"
        case blockWrite = "BlockWrite"
        case cpu
        case memory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cpuPercent = try c.decodeIfPresent(Double.self, forKey: .cpuPercent)
            ?? c.decodeIfPresent(Double.self, forKey: .cpuPercentAlt)
            ?? c.decodeIfPresent(Double.self, forKey: .cpu)
        memoryUsage = try c.decodeIfPresent(Int64.self, forKey: .memoryUsage)
            ?? c.decodeIfPresent(Int64.self, forKey: .memoryUsageAlt)
            ?? c.decodeIfPresent(Int64.self, forKey: .memory)
        memoryLimit = try c.decodeIfPresent(Int64.self, forKey: .memoryLimit)
            ?? c.decodeIfPresent(Int64.self, forKey: .memoryLimitAlt)
        netInput = try c.decodeIfPresent(Int64.self, forKey: .netInput)
        netOutput = try c.decodeIfPresent(Int64.self, forKey: .netOutput)
        blockRead = try c.decodeIfPresent(Int64.self, forKey: .blockRead)
        blockWrite = try c.decodeIfPresent(Int64.self, forKey: .blockWrite)
    }

    var memoryPercent: Double? {
        guard let usage = memoryUsage, let limit = memoryLimit, limit > 0 else { return nil }
        return (Double(usage) / Double(limit)) * 100
    }
}

// MARK: - ANSI / terminal helpers

enum ArcaneTextSanitizer {
    /// Strip CSI/OSC ANSI sequences so PTY output is readable in SwiftUI `Text`.
    static func stripANSI(_ input: String) -> String {
        var s = input
        // ESC[ … final-byte  (CSI)
        if let csi = try? NSRegularExpression(pattern: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#) {
            s = csi.stringByReplacingMatches(
                in: s,
                range: NSRange(s.startIndex..., in: s),
                withTemplate: ""
            )
        }
        // ESC] … BEL/ST  (OSC)
        if let osc = try? NSRegularExpression(pattern: #"\u{001B}\][^\u{0007}\u{001B}]*(\u{0007}|\u{001B}\\)"#) {
            s = osc.stringByReplacingMatches(
                in: s,
                range: NSRange(s.startIndex..., in: s),
                withTemplate: ""
            )
        }
        // Remaining single-char ESC sequences
        if let esc = try? NSRegularExpression(pattern: #"\u{001B}."#) {
            s = esc.stringByReplacingMatches(
                in: s,
                range: NSRange(s.startIndex..., in: s),
                withTemplate: ""
            )
        }
        // Orphaned CSI when ESC (0x1B) is not visible/stored: `[1;32m` `[0m` `[6n` `[H`
        if let orphan = try? NSRegularExpression(pattern: #"\[(?:\d{1,3};){0,8}\d{0,3}[A-Za-z]"#) {
            s = orphan.stringByReplacingMatches(
                in: s,
                range: NSRange(s.startIndex..., in: s),
                withTemplate: ""
            )
        }
        // Carriage returns → newline for Text display (PTY often uses \r alone)
        s = s.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")
        // BEL / backspace cleanup for display
        s = s.replacingOccurrences(of: "\u{0007}", with: "")
        return s
    }

    /// Parse Arcane log WebSocket payloads (`format=json`, optional batch array).
    /// Matches backend `libarcane/ws.LogMessage`: `{ seq, level, message, timestamp, ... }`.
    static func parseLogWSPayload(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return [] }

        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr.compactMap { messageFromLogObject($0) }
        }
        // Single object, or NDJSON-style multi-object frame.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let msg = messageFromLogObject(obj) { return [msg] }
            return []
        }
        // Some proxies may concatenate JSON objects with newlines inside one frame.
        if trimmed.contains("\n") {
            let parts = trimmed.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            let parsed = parts.flatMap { parseLogWSPayload($0) }
            if !parsed.isEmpty { return parsed }
        }
        // Plain text fallback (format=text)
        return [stripANSI(text)]
    }

    private static func messageFromLogObject(_ obj: [String: Any]) -> String? {
        for key in ["message", "Message", "msg", "log"] {
            if let msg = obj[key] as? String {
                let cleaned = stripANSI(msg)
                // Keep empty messages only when the frame is clearly a log object (has level/timestamp).
                if !cleaned.isEmpty { return cleaned }
                if obj["level"] != nil || obj["timestamp"] != nil {
                    return cleaned
                }
            }
        }
        return nil
    }
}

// MARK: - Container summary

struct ArcaneContainer: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let names: [String]?
    let name: String?
    let image: String
    let imageId: String?
    let state: String
    let status: String
    let ports: [ArcanePortMapping]?
    let created: Int64?
    let updateInfo: ArcaneImageUpdateInfo?
    let redeployDisabled: Bool?

    var displayName: String {
        if let names, let first = names.first, !first.isEmpty {
            return first.replacingOccurrences(of: "^/", with: "", options: .regularExpression)
        }
        if let name, !name.isEmpty {
            return name.replacingOccurrences(of: "^/", with: "", options: .regularExpression)
        }
        return String(id.prefix(12))
    }

    var isRunning: Bool {
        let s = state.lowercased()
        return s == "running" || s == "healthy"
    }

    var hasUpdate: Bool { updateInfo?.available == true }

    enum CodingKeys: String, CodingKey {
        case id, names, name, image, imageId, state, status, ports, created, updateInfo, redeployDisabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        names = try c.decodeIfPresent([String].self, forKey: .names)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        image = try c.decodeIfPresent(String.self, forKey: .image) ?? ""
        imageId = try c.decodeIfPresent(String.self, forKey: .imageId)
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? "unknown"
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        ports = try c.decodeIfPresent([ArcanePortMapping].self, forKey: .ports)
        created = try c.decodeIfPresent(Int64.self, forKey: .created)
        // Never fail the whole container list on a bad updateInfo payload.
        updateInfo = try? c.decodeIfPresent(ArcaneImageUpdateInfo.self, forKey: .updateInfo)
        redeployDisabled = try c.decodeIfPresent(Bool.self, forKey: .redeployDisabled)
    }

    struct ArcanePortMapping: Codable, Hashable, Sendable {
        let ip: String?
        let privatePort: Int?
        let publicPort: Int?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case ip, privatePort, publicPort, type
            case IP, PrivatePort, PublicPort
            case legacyType = "Type"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            ip = (try? c.decodeIfPresent(String.self, forKey: .ip))
                ?? (try? c.decodeIfPresent(String.self, forKey: .IP))
            privatePort = (try? c.decodeIfPresent(Int.self, forKey: .privatePort))
                ?? (try? c.decodeIfPresent(Int.self, forKey: .PrivatePort))
            publicPort = (try? c.decodeIfPresent(Int.self, forKey: .publicPort))
                ?? (try? c.decodeIfPresent(Int.self, forKey: .PublicPort))
            type = (try? c.decodeIfPresent(String.self, forKey: .type))
                ?? (try? c.decodeIfPresent(String.self, forKey: .legacyType))
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(ip, forKey: .ip)
            try c.encodeIfPresent(privatePort, forKey: .privatePort)
            try c.encodeIfPresent(publicPort, forKey: .publicPort)
            try c.encodeIfPresent(type, forKey: .type)
        }
    }
}

// MARK: - Container details

struct ArcaneContainerDetails: Codable, Sendable, Identifiable {
    let id: String
    let name: String?
    let image: String?
    let imageId: String?
    let created: String?
    let state: ArcaneContainerState?
    let config: ArcaneContainerConfig?
    let ports: [ArcaneContainer.ArcanePortMapping]?
    let mounts: [ArcaneMount]?
    let labels: [String: String]?
    let redeployDisabled: Bool?
    let composeInfo: ArcaneComposeInfo?

    var displayName: String {
        (name ?? "").replacingOccurrences(of: "^/", with: "", options: .regularExpression)
    }

    var isRunning: Bool { state?.running == true }
}

struct ArcaneContainerState: Codable, Sendable {
    let status: String?
    let running: Bool?
    let startedAt: String?
    let finishedAt: String?
    let exitCode: Int?
    let health: ArcaneContainerHealth?
}

struct ArcaneContainerHealth: Codable, Sendable {
    let status: String?
    let failingStreak: Int?
}

struct ArcaneContainerConfig: Codable, Sendable {
    let env: [String]?
    let cmd: [String]?
    let entrypoint: [String]?
    let workingDir: String?
    let user: String?
}

struct ArcaneMount: Codable, Sendable, Identifiable {
    let type: String?
    let name: String?
    let source: String?
    let destination: String?
    let driver: String?
    let mode: String?
    let rw: Bool?

    var id: String { "\(source ?? "")->\(destination ?? UUID().uuidString)" }
}

struct ArcaneComposeInfo: Codable, Sendable {
    let projectName: String?
    let serviceName: String?
    let workingDir: String?
    let configFiles: String?
}

// MARK: - Docker host info (raw Docker API shape, not always wrapped)

struct ArcaneDockerInfo: Codable, Sendable {
    let name: String?
    let containers: Int?
    let containersRunning: Int?
    let containersPaused: Int?
    let containersStopped: Int?
    let images: Int?
    let driver: String?
    let memTotal: Int64?
    let ncpu: Int?
    let serverVersion: String?
    let operatingSystem: String?
    let architecture: String?
    let kernelVersion: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case containers = "Containers"
        case containersRunning = "ContainersRunning"
        case containersPaused = "ContainersPaused"
        case containersStopped = "ContainersStopped"
        case images = "Images"
        case driver = "Driver"
        case memTotal = "MemTotal"
        case ncpu = "NCPU"
        case serverVersion = "ServerVersion"
        case operatingSystem = "OperatingSystem"
        case architecture = "Architecture"
        case kernelVersion = "KernelVersion"
    }
}

// MARK: - Actions

struct ArcaneActionResult: Codable, Sendable {
    let success: Bool?
    let activityId: String?
    let message: String?
    let started: [String]?
    let stopped: [String]?
    let failed: [String]?
    let errors: [String]?
}

struct ArcaneMessageBody: Codable, Sendable {
    let message: String?
    let activityId: String?
}

// MARK: - Updater result (POST .../update and .../updater/run)

struct ArcaneUpdaterResult: Codable, Sendable {
    let success: Bool?
    let checked: Int?
    let updated: Int?
    let restarted: Int?
    let skipped: Int?
    let failed: Int?
    let startTime: String?
    let endTime: String?
    let duration: String?
    let items: [ArcaneUpdaterResourceResult]?
    let activityId: String?

    var updatedCount: Int { (updated ?? 0) + (restarted ?? 0) }
    var failedCount: Int { failed ?? 0 }
    var skippedCount: Int { skipped ?? 0 }

    var firstFailureMessage: String? {
        items?.first(where: { ($0.status ?? "").lowercased() == "failed" })?.error
    }

    /// Human-readable summary for banners / alerts.
    var userFacingSummary: String {
        if failedCount > 0, updatedCount > 0 {
            return "Updated \(updatedCount), failed \(failedCount)"
        }
        if failedCount > 0 {
            return firstFailureMessage ?? "Update failed (\(failedCount))"
        }
        if updatedCount > 0 {
            return "Updated \(updatedCount) resource(s)"
        }
        if skippedCount > 0 {
            return "Already up to date"
        }
        return "No updates applied"
    }

    var didApplyUpdate: Bool { updatedCount > 0 }
    var didFail: Bool { failedCount > 0 }
}

struct ArcaneUpdaterResourceResult: Codable, Sendable {
    let resourceId: String?
    let resourceName: String?
    let resourceType: String?
    let status: String?
    let updateAvailable: Bool?
    let updateApplied: Bool?
    let error: String?
}

// MARK: - Background activities (update / pull progress)

struct ArcaneActivity: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let environmentId: String?
    let batchId: String?
    let type: String?
    let status: String?
    let resourceType: String?
    let resourceId: String?
    let resourceName: String?
    let progress: Int?
    let step: String?
    let latestMessage: String?
    let startedAt: String?
    let endedAt: String?
    let durationMs: Int64?
    let error: String?

    var isTerminal: Bool {
        switch (status ?? "").lowercased() {
        case "success", "failed", "cancelled": return true
        default: return false
        }
    }

    var isActive: Bool {
        switch (status ?? "").lowercased() {
        case "running", "queued": return true
        default: return false
        }
    }
}

struct ArcaneActivityMessage: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let activityId: String?
    let level: String?
    let message: String
    let createdAt: String?
}

struct ArcaneActivityDetail: Codable, Sendable {
    let activity: ArcaneActivity
    let messages: [ArcaneActivityMessage]?
}

enum ArcaneContainerAction: String, Codable, CaseIterable, Sendable {
    case start, stop, restart, kill, pause, unpause

    var symbolName: String {
        switch self {
        case .start: return "play.fill"
        case .stop: return "stop.fill"
        case .restart: return "arrow.clockwise"
        case .kill: return "xmark.octagon.fill"
        case .pause: return "pause.fill"
        case .unpause: return "play.pause.fill"
        }
    }
}
