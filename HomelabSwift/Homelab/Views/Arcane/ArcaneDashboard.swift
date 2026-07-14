import SwiftUI

struct ArcaneDashboard: View {
    @Environment(ServicesStore.self) private var servicesStore

    let instanceId: UUID

    @State private var containers: [ArcaneContainer] = []
    @State private var isLoading = true
    @State private var actionInProgress: Set<String> = []

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if containers.isEmpty {
                Text("无容器")
                    .foregroundStyle(AppTheme.textMuted)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(containers) { container in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(statusColor(for: container.state))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(container.name.replacingOccurrences(of: "^/", with: "", options: .regularExpression))
                                .font(.body.weight(.medium))
                            Text(container.image)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        if container.isRunning {
                            Button("停止") {
                                performAction(.stop, on: container.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(AppTheme.stopped)
                        } else {
                            Button("启动") {
                                performAction(.start, on: container.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(AppTheme.running)
                        }
                    }
                    .opacity(actionInProgress.contains(container.id) ? 0.5 : 1.0)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(Color.clear)
                .glassEffect(Glass.regular, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        }
        .navigationTitle("Arcane")
        .task { await fetchContainers() }
        .refreshable { await fetchContainers() }
    }

    private func fetchContainers() async {
        guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
        do {
            containers = try await client.getContainers()
        } catch {}
        isLoading = false
    }

    private func performAction(_ action: ContainerAction, on id: String) {
        Task {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
            actionInProgress.insert(id)
            do {
                try await client.containerAction(id: id, action: action)
                await fetchContainers()
            } catch {}
            actionInProgress.remove(id)
        }
    }

    private func statusColor(for state: String) -> Color {
        switch state.lowercased() {
        case "running": return AppTheme.running
        case "exited": return .gray
        default: return AppTheme.warning
        }
    }
}
