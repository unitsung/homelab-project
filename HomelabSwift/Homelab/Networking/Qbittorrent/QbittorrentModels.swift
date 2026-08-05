import Foundation

// MARK: - API Models

struct QbittorrentTorrent: Decodable, Identifiable, Sendable {
    let hash: String
    let name: String
    let size: Int64
    let state: String
    let progress: Double
    let dlspeed: Int64
    let upspeed: Int64
    let eta: Int64
    let downloaded: Int64
    let uploaded: Int64
    let ratio: Double?
    let num_seeds: Int?
    let num_leechs: Int?
    let category: String?
    let tags: String?

    var id: String { hash }

    private var normalizedState: String { state.lowercased() }

    var isPaused: Bool {
        let pausedStates: Set<String> = ["pauseddl", "pausedup", "stoppeddl", "stoppedup"]
        return pausedStates.contains(normalizedState)
            || normalizedState.hasPrefix("paused")
            || normalizedState.hasPrefix("stopped")
    }

    var isChecking: Bool {
        normalizedState.contains("checking") || normalizedState == "allocating"
    }

    var isError: Bool {
        normalizedState.contains("error") || normalizedState == "missingfiles"
    }

    var isDownloading: Bool {
        let downloadingStates: Set<String> = ["downloading", "forceddl", "metadl", "stalleddl", "queueddl"]
        return downloadingStates.contains(normalizedState)
    }

    var isUploading: Bool {
        let uploadingStates: Set<String> = ["uploading", "forcedup", "stalledup", "queuedup"]
        return uploadingStates.contains(normalizedState)
    }
}

struct QbittorrentTransferInfo: Decodable, Sendable {
    let connection_status: String
    let dl_info_speed: Int64
    let up_info_speed: Int64
    let dl_info_data: Int64
    let up_info_data: Int64
    let dht_nodes: Int?
    let free_space_on_disk: Int64?
    /// True when alternative (scheduled/“slow”) speed limits are active.
    /// qB may emit JSON bool or 0/1 depending on version.
    let use_alt_speed_limits: Bool?

    var isAltSpeedLimitsEnabled: Bool { use_alt_speed_limits == true }

    enum CodingKeys: String, CodingKey {
        case connection_status
        case dl_info_speed
        case up_info_speed
        case dl_info_data
        case up_info_data
        case dht_nodes
        case free_space_on_disk
        case use_alt_speed_limits
    }

    init(
        connection_status: String,
        dl_info_speed: Int64,
        up_info_speed: Int64,
        dl_info_data: Int64,
        up_info_data: Int64,
        dht_nodes: Int?,
        free_space_on_disk: Int64?,
        use_alt_speed_limits: Bool?
    ) {
        self.connection_status = connection_status
        self.dl_info_speed = dl_info_speed
        self.up_info_speed = up_info_speed
        self.dl_info_data = dl_info_data
        self.up_info_data = up_info_data
        self.dht_nodes = dht_nodes
        self.free_space_on_disk = free_space_on_disk
        self.use_alt_speed_limits = use_alt_speed_limits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        connection_status = try c.decode(String.self, forKey: .connection_status)
        dl_info_speed = try c.decode(Int64.self, forKey: .dl_info_speed)
        up_info_speed = try c.decode(Int64.self, forKey: .up_info_speed)
        dl_info_data = try c.decode(Int64.self, forKey: .dl_info_data)
        up_info_data = try c.decode(Int64.self, forKey: .up_info_data)
        dht_nodes = try c.decodeIfPresent(Int.self, forKey: .dht_nodes)
        free_space_on_disk = try c.decodeIfPresent(Int64.self, forKey: .free_space_on_disk)
        use_alt_speed_limits = Self.decodeFlexibleBool(c, forKey: .use_alt_speed_limits)
    }

    /// Copy with flipped/set alt-speed flag (optimistic UI after toggle).
    func withAltSpeedLimits(_ enabled: Bool) -> QbittorrentTransferInfo {
        QbittorrentTransferInfo(
            connection_status: connection_status,
            dl_info_speed: dl_info_speed,
            up_info_speed: up_info_speed,
            dl_info_data: dl_info_data,
            up_info_data: up_info_data,
            dht_nodes: dht_nodes,
            free_space_on_disk: free_space_on_disk,
            use_alt_speed_limits: enabled
        )
    }

    private static func decodeFlexibleBool(
        _ c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool? {
        if let b = try? c.decodeIfPresent(Bool.self, forKey: key) { return b }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i != 0 }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) {
            let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes", "on"].contains(lower) { return true }
            if ["0", "false", "no", "off"].contains(lower) { return false }
        }
        return nil
    }
}

/// File entry from `GET /api/v2/torrents/files`.
struct QbittorrentTorrentFile: Decodable, Identifiable, Sendable, Hashable {
    let name: String
    let size: Int64
    let progress: Double
    let priority: Int?

    var id: String { name }

    var progressPercent: Int {
        Int((min(max(progress, 0), 1) * 100).rounded())
    }
}

/// Tracker entry from `GET /api/v2/torrents/trackers`.
struct QbittorrentTracker: Decodable, Identifiable, Sendable, Hashable {
    let url: String
    let status: Int?
    let num_peers: Int?
    let num_seeds: Int?
    let num_leeches: Int?
    let msg: String?

    var id: String { url }

    var statusLabel: String {
        switch status {
        case 0: return "Disabled"
        case 1: return "Not contacted"
        case 2: return "Working"
        case 3: return "Updating"
        case 4: return "Not working"
        default: return msg?.isEmpty == false ? (msg ?? "—") : "—"
        }
    }
}
