import SwiftUI
import Charts

struct CPUMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore

    @State private var cpuPercent: Double = 0
    @State private var lastError: String?

    var body: some View {
        DashboardCard(title: "CPU", icon: "cpu") {
            VStack(spacing: 8) {
                Gauge(value: cpuPercent, in: 0...100) {
                    Text("\(Int(cpuPercent))%")
                        .font(.title2.bold())
                } currentValueLabel: {
                    Text("CPU")
                        .font(.caption2)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(cpuPercent > 80 ? AppTheme.stopped : cpuPercent > 60 ? AppTheme.warning : AppTheme.running)

                if let error = lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.stopped)
                }
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchCPU()
        }
    }

    private func fetchCPU() async {
        await systemStore.refresh(servicesStore: servicesStore)
        if let info = systemStore.systemInfo {
            cpuPercent = info.cpuValue
            lastError = nil
        } else if let error = systemStore.lastError {
            lastError = error
        }
    }
}
