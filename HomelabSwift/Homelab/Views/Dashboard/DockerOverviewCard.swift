import SwiftUI

struct DockerOverviewCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore
    @Environment(Localizer.self) private var localizer

    @State private var totalContainers: Int = 0
    @State private var runningContainers: Int = 0
    @State private var imageCount: Int = 0
    @State private var aggCpu: Double = 0

    /// Prefer Arcane → Portainer → Beszel for docker management entry.
    private var dockerRoute: HomeServiceRoute? {
        if let inst = servicesStore.preferredInstance(for: .arcane) {
            return HomeServiceRoute(type: .arcane, instanceId: inst.id)
        }
        if let inst = servicesStore.preferredInstance(for: .portainer) {
            return HomeServiceRoute(type: .portainer, instanceId: inst.id)
        }
        if let inst = servicesStore.preferredInstance(for: .beszel) {
            return HomeServiceRoute(type: .beszel, instanceId: inst.id)
        }
        return nil
    }

    var body: some View {
        Group {
            if let route = dockerRoute {
                NavigationLink(value: route) {
                    cardContent
                }
                .buttonStyle(TilePressButtonStyle())
            } else {
                cardContent
            }
        }
        .task(id: coordinator.refreshTrigger) { await fetchData() }
    }

    private var cardContent: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shippingbox").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.info)
                Text(localizer.t.homeDockerLabel).font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            if totalContainers > 0 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    stat("总量", "\(totalContainers)")
                    stat("运行中", "\(runningContainers)", accent: AppTheme.running)
                    stat("镜像", "\(imageCount)")
                    stat("CPU", String(format: "%.0f%%", aggCpu))
                }
            } else {
                Text(localizer.t.noData).font(.subheadline).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassCard()
    }

    private func stat(_ label: String, _ value: String, accent: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.body, design: .rounded).weight(.bold).monospacedDigit()).foregroundStyle(accent ?? .primary)
            Text(label).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func fetchData() async {
        await systemStore.refresh(servicesStore: servicesStore)
        guard let systemId = systemStore.firstSystemId,
              let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else {
            totalContainers = 0; runningContainers = 0; imageCount = 0; aggCpu = 0; return
        }
        do {
            let containers = try await client.getContainers(systemId: systemId)
            totalContainers = containers.count
            runningContainers = containers.filter { isRunning($0) }.count
            imageCount = Set(containers.compactMap { $0.image?.split(separator: ":").first.map(String.init) }).count
            aggCpu = containers.reduce(0) { $0 + $1.cpuValue }
        } catch {}
    }

    private func isRunning(_ c: BeszelContainerRecord) -> Bool {
        let s = (c.status ?? "").lowercased()
        if s.contains("up") || s.contains("running") { return true }
        if s.contains("exited") || s.contains("dead") || s.contains("created") { return false }
        return c.health == .healthy || c.health == .starting
    }
}
