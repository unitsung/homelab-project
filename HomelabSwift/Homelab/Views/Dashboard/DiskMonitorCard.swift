import SwiftUI
import Charts

struct DiskMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var diskUsedGB: Double = 0
    @State private var diskFreeGB: Double = 0
    @State private var diskPercent: Double = 0

    var body: some View {
        DashboardCard(title: "磁盘", icon: "externaldrive") {
            VStack(spacing: 8) {
                Chart {
                    SectorMark(angle: .value("已用", diskUsedGB), innerRadius: .ratio(0.6))
                        .foregroundStyle(AppTheme.info)
                    SectorMark(angle: .value("可用", diskFreeGB), innerRadius: .ratio(0.6))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
                .frame(height: 80)

                Text("已用 \(Int(diskPercent))%")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchDisk()
        }
    }

    private func fetchDisk() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let response = try await client.getSystems()
            guard let info = response.items.first?.info else { return }
            diskPercent = info.dpValue
            diskUsedGB = info.duValue > 0 ? info.duValue : info.dValue
            diskFreeGB = max(0, (diskUsedGB / max(diskPercent, 0.1) * 100) - diskUsedGB)
        } catch {}
    }
}
