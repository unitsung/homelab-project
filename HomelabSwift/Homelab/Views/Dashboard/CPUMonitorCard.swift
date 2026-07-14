import SwiftUI
import Charts

struct CPUMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var cpuPercent: Double = 0

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
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchCPU()
        }
    }

    private func fetchCPU() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let response = try await client.getSystems()
            guard let info = response.items.first?.info else { return }
            cpuPercent = info.cpuValue
        } catch {}
    }
}
