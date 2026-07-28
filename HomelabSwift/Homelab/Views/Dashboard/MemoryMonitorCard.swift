import SwiftUI

struct MemoryMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore
    @Environment(Localizer.self) private var localizer

    @State private var usedGB: Double = 0
    @State private var totalGB: Double = 0
    @State private var percent: Double = 0
    @State private var lastError: String?

    private var tint: Color {
        percent > 85 ? AppTheme.stopped : percent > 70 ? AppTheme.warning : AppTheme.info
    }

    var body: some View {
        VStack(spacing: 10) {
            circularGauge(
                percent: percent,
                label: localizer.t.overviewMemoryLabel,
                color: tint
            )

            Text(detailText)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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
            await fetchMemory()
        }
    }

    private var detailText: String {
        if totalGB > 0 {
            return String(format: "%.1f GB / %.1f GB", usedGB, totalGB)
        }
        if percent > 0 {
            return String(format: "%.0f%%", percent)
        }
        return "— / —"
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

    private func fetchMemory() async {
        await systemStore.refresh(servicesStore: servicesStore)
        usedGB = systemStore.memoryUsedGB
        totalGB = systemStore.memoryTotalGB
        percent = systemStore.memoryPercent
        lastError = (usedGB <= 0 && totalGB <= 0 && percent <= 0) ? systemStore.lastError : nil
    }
}
