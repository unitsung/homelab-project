import Foundation
import Observation

@MainActor
@Observable
final class DashboardSystemStore {
    var systemInfo: BeszelSystemInfo?
    var latestStats: BeszelRecordStats?
    var firstSystemId: String?
    var lastError: String?

    private var refreshTask: Task<Void, Never>?

    func refresh(servicesStore: ServicesStore) async {
        if let existingTask = refreshTask {
            await existingTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            guard let instance = servicesStore.preferredInstance(for: .beszel),
                  let client = await servicesStore.beszelClient(instanceId: instance.id) else {
                lastError = nil
                return
            }
            do {
                let response = try await client.getSystems()
                let primary = response.items.first
                systemInfo = primary?.info
                firstSystemId = primary?.id
                lastError = nil

                // system_stats has accurate memory/disk/efs (ZFS etc.)
                if let systemId = primary?.id {
                    if let records = try? await client.getSystemRecords(systemId: systemId, limit: 1) {
                        latestStats = records.items.first?.stats
                    }
                }
            } catch {
                lastError = error.localizedDescription
            }
            refreshTask = nil
        }
        refreshTask = task
        await task.value
    }

    /// Memory used GB preferring latest system_stats, then systems.info.
    var memoryUsedGB: Double {
        if let used = latestStats?.memoryUsedGb, used > 0 { return used }
        let total = memoryTotalGB
        if total > 0 {
            let mp = latestStats?.mpValue ?? systemInfo?.mpValue ?? 0
            if mp > 0 { return total * mp / 100 }
        }
        return systemInfo?.mValue ?? 0
    }

    var memoryTotalGB: Double {
        if let total = latestStats?.memoryTotalGb, total > 0 { return total }
        let mt = systemInfo?.mtValue ?? 0
        if mt > 0 { return mt }
        // Some Beszel versions put total in `m` when `mt` is missing.
        return systemInfo?.mValue ?? 0
    }

    var memoryPercent: Double {
        if let mp = latestStats?.mp, mp > 0 { return min(max(mp, 0), 100) }
        if let mp = systemInfo?.mp, mp > 0 { return min(max(mp, 0), 100) }
        let total = memoryTotalGB
        guard total > 0 else { return 0 }
        return min(max(memoryUsedGB / total * 100, 0), 100)
    }

    var rootDiskUsedGB: Double {
        if let du = latestStats?.du, du > 0 { return du }
        if let d = latestStats?.d, d > 0, let dp = latestStats?.dp, dp > 0 {
            // In system_stats, `d` is total capacity.
            return d * dp / 100
        }
        let du = systemInfo?.duValue ?? 0
        if du > 0 { return du }
        // systemInfo.d is used capacity in older Beszel payloads.
        return systemInfo?.dValue ?? 0
    }

    var rootDiskTotalGB: Double {
        if let dt = latestStats?.dt, dt > 0 { return dt }
        // In system_stats, `d` is disk total (GB).
        if let d = latestStats?.d, d > 0 { return d }
        let dtInfo = systemInfo?.dtValue ?? 0
        if dtInfo > 0 { return dtInfo }

        // Derive total from used + percent using raw fields only.
        // Do NOT call rootDiskPercent here — that property calls rootDiskTotalGB
        // and previously caused infinite recursion → stack overflow (EXC_BAD_ACCESS).
        let used: Double = {
            if let du = latestStats?.du, du > 0 { return du }
            let duInfo = systemInfo?.duValue ?? 0
            if duInfo > 0 { return duInfo }
            // Older systemInfo: `d` is used capacity (not total).
            return systemInfo?.dValue ?? 0
        }()
        let dp: Double = {
            if let dp = latestStats?.dp, dp > 0 { return dp }
            return systemInfo?.dpValue ?? 0
        }()
        if used > 0, dp > 0 {
            return used / dp * 100
        }
        return 0
    }

    var rootDiskPercent: Double {
        if let dp = latestStats?.dp, dp > 0 { return min(max(dp, 0), 100) }
        if let dp = systemInfo?.dp, dp > 0 { return min(max(dp, 0), 100) }
        let total = rootDiskTotalGB
        guard total > 0 else { return 0 }
        return min(max(rootDiskUsedGB / total * 100, 0), 100)
    }

    /// Root + external filesystems (ZFS pools, mounts) from system_stats.efs.
    var filesystems: [(label: String, usedGB: Double, totalGB: Double, percent: Double)] {
        var result: [(label: String, usedGB: Double, totalGB: Double, percent: Double)] = []
        let rootUsed = rootDiskUsedGB
        let rootTotal = rootDiskTotalGB
        let rootPct = rootDiskPercent
        if rootTotal > 0 || rootPct > 0 {
            result.append((label: "/", usedGB: rootUsed, totalGB: rootTotal, percent: rootPct))
        }

        if let efs = latestStats?.efs {
            for (key, entry) in efs.sorted(by: { $0.key < $1.key }) {
                let total = entry.d ?? 0
                let used = entry.du ?? 0
                let percent: Double
                if total > 0 {
                    percent = min(max(used / total * 100, 0), 100)
                } else if let infoPct = systemInfo?.efs?[key] ?? nil {
                    percent = min(max(infoPct, 0), 100)
                } else {
                    percent = 0
                }
                result.append((label: key, usedGB: used, totalGB: total, percent: percent))
            }
        } else if let efs = systemInfo?.efs {
            for (key, pctOpt) in efs.sorted(by: { $0.key < $1.key }) {
                guard let pct = pctOpt else { continue }
                result.append((label: key, usedGB: 0, totalGB: 0, percent: min(max(pct, 0), 100)))
            }
        }
        return result
    }
}
