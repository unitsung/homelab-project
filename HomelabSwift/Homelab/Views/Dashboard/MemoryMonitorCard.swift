import SwiftUI
import Charts

struct MemoryMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var usedGB: Double = 0
    @State private var cachedGB: Double = 0
    @State private var freeGB: Double = 0
    @State private var totalGB: Double = 0

    var body: some View {
        DashboardCard(title: "内存", icon: "memorychip") {
            VStack(spacing: 8) {
                Chart {
                    BarMark(x: .value("", "已用"), y: .value("GB", usedGB))
                        .foregroundStyle(AppTheme.info)
                    BarMark(x: .value("", "缓存"), y: .value("GB", cachedGB))
                        .foregroundStyle(AppTheme.running)
                    BarMark(x: .value("", "空闲"), y: .value("GB", freeGB))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(values: .automatic) }
                .frame(height: 60)

                Text("\(Int(usedGB)) GB / \(Int(totalGB)) GB")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchMemory()
        }
    }

    private func fetchMemory() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let response = try await client.getSystems()
            guard let info = response.items.first?.info else { return }
            totalGB = info.mtValue
            usedGB = info.mValue
            let cached = max(0, totalGB - usedGB)
            cachedGB = cached * 0.3
            freeGB = cached - cachedGB
        } catch {}
    }
}
