import Foundation

struct TrueNASSystemInfo: Equatable, Sendable {
    let version: String
    let hostname: String?
    let uptime: String?
    let systemProduct: String?
}

struct TrueNASPool: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let status: String
    let healthy: Bool
    let sizeBytes: Double
    let usedBytes: Double
    let availableBytes: Double

    var usedPercent: Double {
        guard sizeBytes > 0 else { return 0 }
        return min(max((usedBytes / sizeBytes) * 100, 0), 100)
    }
}

struct TrueNASDisk: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let model: String?
    let serial: String?
    let sizeBytes: Double
    let pool: String?
}

struct TrueNASAlert: Identifiable, Equatable, Sendable {
    let id: String
    let level: String
    let message: String
    let createdAt: String?
}

struct TrueNASServiceStatus: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let state: String
    let enabled: Bool
    let running: Bool
}

struct TrueNASShareSummary: Equatable, Sendable {
    let smbCount: Int
    let nfsCount: Int
    let iscsiCount: Int

    var totalCount: Int {
        smbCount + nfsCount + iscsiCount
    }
}

struct TrueNASWorkloadSummary: Equatable, Sendable {
    let appsTotal: Int
    let appsRunning: Int
    let virtualMachinesTotal: Int
    let virtualMachinesRunning: Int

    var hasWorkloads: Bool {
        appsTotal > 0 || virtualMachinesTotal > 0
    }
}

struct TrueNASDashboardSnapshot: Equatable, Sendable {
    let system: TrueNASSystemInfo
    let pools: [TrueNASPool]
    let disks: [TrueNASDisk]
    let alerts: [TrueNASAlert]
    let services: [TrueNASServiceStatus]
    let shareSummary: TrueNASShareSummary
    let workloadSummary: TrueNASWorkloadSummary

    var healthyPoolCount: Int {
        pools.filter(\.healthy).count
    }

    var totalStorageBytes: Double {
        pools.reduce(0) { $0 + $1.sizeBytes }
    }

    var usedStorageBytes: Double {
        pools.reduce(0) { $0 + $1.usedBytes }
    }

    var storageUsedPercent: Double {
        guard totalStorageBytes > 0 else { return 0 }
        return min(max((usedStorageBytes / totalStorageBytes) * 100, 0), 100)
    }
}
