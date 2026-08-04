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
    let use_alt_speed_limits: Bool?
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
