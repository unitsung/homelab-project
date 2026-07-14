import SwiftUI

struct SystemHealthCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var isOnline: Bool = false
    @State private var hostname: String = "--"
    @State private var uptime: String = "--"

    var body: some View {
        DashboardCard(title: "系统健康", icon: "heart.circle.fill") {
            HStack(spacing: 12) {
                Circle()
                    .fill(isOnline ? AppTheme.running : AppTheme.stopped)
                    .frame(width: 12, height: 12)
                Text(isOnline ? "在线" : "离线")
                    .font(.title3.bold())
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hostname)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(uptime)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .lineLimit(1)
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchSystemHealth()
        }
    }

    private func fetchSystemHealth() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else {
            isOnline = false
            return
        }
        do {
            let response = try await client.getSystems()
            guard let system = response.items.first else {
                isOnline = false
                return
            }
            isOnline = system.isOnline
            hostname = system.info?.h ?? system.name
            let seconds = system.info?.uValue ?? 0
            uptime = seconds > 0 ? formatUptime(seconds) : "--"
        } catch {
            isOnline = false
        }
    }

    private func formatUptime(_ seconds: Double) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h"
    }
}
