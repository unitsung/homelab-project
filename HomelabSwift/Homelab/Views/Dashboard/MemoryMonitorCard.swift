import SwiftUI
import Charts

struct MemoryMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore

    @State private var usedGB: Double = 0
    @State private var cachedGB: Double = 0
    @State private var freeGB: Double = 0
    @State private var totalGB: Double = 0
    @State private var lastError: String?

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

                if let error = lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.stopped)
                }
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchMemory()
        }
    }

    private func fetchMemory() async {
        await systemStore.refresh(servicesStore: servicesStore)
        if let info = systemStore.systemInfo {
            totalGB = info.mtValue
            usedGB = info.mValue
            let cached = max(0, totalGB - usedGB)
            cachedGB = cached * 0.3
            freeGB = cached - cachedGB
            lastError = nil
        } else if let error = systemStore.lastError {
            lastError = error
        }
    }
}
