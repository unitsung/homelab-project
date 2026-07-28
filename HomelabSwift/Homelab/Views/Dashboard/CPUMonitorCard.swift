import SwiftUI

struct CPUMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore
    @Environment(Localizer.self) private var localizer

    @State private var cpuPercent: Double = 0
    @State private var lastError: String?

    private var tint: Color {
        cpuPercent > 80 ? AppTheme.stopped : cpuPercent > 60 ? AppTheme.warning : AppTheme.running
    }

    var body: some View {
        VStack(spacing: 10) {
            circularGauge(
                percent: cpuPercent,
                label: localizer.t.overviewCpuLabel,
                color: tint
            )

            Text(String(format: "%.1f%%", cpuPercent))
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            if let error = lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.stopped)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard()
        .task(id: coordinator.refreshTrigger) {
            await fetchCPU()
        }
    }

    private func circularGauge(percent: Double, label: String, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(max(percent, 0) / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: percent)
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", percent))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .frame(width: 80, height: 80)
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
