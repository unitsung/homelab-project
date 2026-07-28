import SwiftUI

struct SystemHealthCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(Localizer.self) private var localizer

    @State private var isOnline: Bool = false
    @State private var hostname: String = "--"
    @State private var uptime: String = "--"
    @State private var totalSystems: Int = 0
    @State private var onlineSystems: Int = 0
    @State private var avgCpu: Double = 0
    @State private var avgMem: Double = 0
    @State private var avgDisk: Double = 0

    private let accent = AppTheme.accent

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.body)
                    .foregroundStyle(isOnline ? accent : AppTheme.textMuted)
                    .frame(width: 36, height: 36)
                    .background(
                        (isOnline ? accent : AppTheme.textMuted).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(hostname)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isOnline ? AppTheme.running : AppTheme.stopped)
                            .frame(width: 6, height: 6)
                        Text(isOnline ? localizer.t.portainerOnline : localizer.t.portainerOffline)
                            .font(.caption2)
                            .foregroundStyle(isOnline ? AppTheme.running : AppTheme.stopped)
                    }
                }

                Spacer()

                if isOnline {
                    Text(uptime)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }

            if isOnline {
                HStack(spacing: 8) {
                    resourceBar(label: localizer.t.overviewCpuLabel, percent: avgCpu, color: accent)
                    resourceBar(label: localizer.t.overviewMemoryLabel, percent: avgMem, color: AppTheme.info)
                    if avgDisk > 0 {
                        resourceBar(label: localizer.t.homeDiskUsage, percent: avgDisk, color: AppTheme.paused)
                    }
                }
            }

            if totalSystems > 1 {
                HStack(spacing: 4) {
                    Text("\(onlineSystems)/\(totalSystems)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(14)
        .glassCard(tint: isOnline ? nil : Color.red.opacity(0.05))
        .task(id: coordinator.refreshTrigger) {
            await fetchSystemHealth()
        }
    }

    private func resourceBar(label: String, percent: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Text(String(format: "%.0f%%", percent))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * min(max(percent, 0) / 100, 1), 3), height: 5)
                        .animation(.easeOut(duration: 0.5), value: percent)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    private func fetchSystemHealth() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else {
            isOnline = false
            return
        }
        do {
            let response = try await client.getSystems()
            let systems = response.items
            totalSystems = systems.count
            let online = systems.filter { $0.info != nil && $0.isOnline }
            onlineSystems = online.count

            guard let primary = systems.first else {
                isOnline = false
                return
            }
            isOnline = primary.isOnline
            hostname = primary.info?.h ?? primary.name
            let seconds = primary.info?.uValue ?? 0
            uptime = seconds > 0 ? formatUptime(seconds) : "--"

            if !online.isEmpty {
                let cpuValues = online.compactMap { $0.info?.cpu }
                let memValues = online.compactMap { $0.info?.mp }
                let diskValues = online.compactMap { $0.info?.dp }
                avgCpu = cpuValues.isEmpty ? 0 : cpuValues.reduce(0, +) / Double(cpuValues.count)
                avgMem = memValues.isEmpty ? 0 : memValues.reduce(0, +) / Double(memValues.count)
                avgDisk = diskValues.isEmpty ? 0 : diskValues.reduce(0, +) / Double(diskValues.count)
            }
        } catch {
            isOnline = false
        }
    }

    private func formatUptime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
