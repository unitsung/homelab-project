import SwiftUI

struct DiskMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore
    @Environment(Localizer.self) private var localizer

    @State private var filesystems: [(label: String, usedGB: Double, totalGB: Double, percent: Double)] = []

    private var primaryPercent: Double {
        filesystems.first?.percent ?? 0
    }

    private var tint: Color {
        primaryPercent > 90 ? AppTheme.stopped : primaryPercent > 75 ? AppTheme.warning : AppTheme.paused
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizer.t.homeDiskUsage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Text(String(format: "%.0f%%", primaryPercent))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
            }

            if filesystems.isEmpty {
                Text(localizer.t.noData)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(filesystems.prefix(4).enumerated()), id: \.offset) { _, fs in
                        filesystemRow(fs)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
        .task(id: coordinator.refreshTrigger) {
            await fetchDisk()
        }
    }

    private func filesystemRow(_ fs: (label: String, usedGB: Double, totalGB: Double, percent: Double)) -> some View {
        let color: Color = fs.percent > 90 ? AppTheme.stopped : fs.percent > 75 ? AppTheme.warning : AppTheme.paused
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fs.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if fs.totalGB > 0 {
                    Text(String(format: "%.0f/%.0fG", fs.usedGB, fs.totalGB))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text(String(format: "%.0f%%", fs.percent))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * min(max(fs.percent, 0) / 100, 1), 3), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private func fetchDisk() async {
        await systemStore.refresh(servicesStore: servicesStore)
        filesystems = systemStore.filesystems
    }
}
