import SwiftUI

struct DockerOverviewCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var containers: [ArcaneContainer] = []
    @State private var runningCount: Int = 0

    var body: some View {
        DashboardCard(title: "Docker", icon: "shippingbox") {
            VStack(spacing: 10) {
                HStack {
                    Label("\(runningCount)/\(containers.count)", systemImage: "circle.fill")
                        .foregroundStyle(AppTheme.running)
                        .font(.title3.bold())
                    Spacer()
                }

                if containers.isEmpty {
                    Text("无容器数据")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(containers) { container in
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(container.isRunning ? AppTheme.running : AppTheme.stopped)
                                        .frame(width: 10, height: 10)
                                    Text(container.name.replacingOccurrences(of: "^/", with: "", options: .regularExpression))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 80)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchContainers()
        }
    }

    private func fetchContainers() async {
        guard let instance = servicesStore.preferredInstance(for: .arcane),
              let client = await servicesStore.arcaneClient(instanceId: instance.id) else { return }
        do {
            containers = try await client.getContainers()
            runningCount = containers.filter(\.isRunning).count
        } catch {}
    }
}
