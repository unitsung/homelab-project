import SwiftUI

struct TrueNASDashboard: View {
    let instanceId: UUID

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer

    @State private var selectedInstanceId: UUID
    @State private var snapshot: TrueNASDashboardSnapshot?
    @State private var state: LoadableState<Void> = .idle

    private let accent = ServiceType.truenas.colors.primary
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(instanceId: UUID) {
        self.instanceId = instanceId
        _selectedInstanceId = State(initialValue: instanceId)
    }

    var body: some View {
        ServiceDashboardLayout(
            serviceType: .truenas,
            instanceId: selectedInstanceId,
            state: state,
            onRefresh: fetchDashboard
        ) {
            instancePicker
            readOnlyNotice

            if let snapshot {
                overview(snapshot)
                systemCard(snapshot.system)
                shareSection(snapshot.shareSummary)
                workloadSection(snapshot.workloadSummary)
                serviceSection(snapshot.services)
                poolSection(snapshot.pools)
                diskSection(snapshot.disks)
                alertSection(snapshot.alerts)
            }
        }
        .navigationTitle(localizer.t.truenasDashboard)
        .task(id: selectedInstanceId) {
            await fetchDashboard()
        }
    }

    private var instancePicker: some View {
        let instances = servicesStore.instances(for: .truenas)
        return Group {
            if instances.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localizer.t.dashboardInstances)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)
                        .textCase(.uppercase)

                    ForEach(instances) { instance in
                        Button {
                            HapticManager.light()
                            selectedInstanceId = instance.id
                            servicesStore.setPreferredInstance(id: instance.id, for: .truenas)
                            snapshot = nil
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(instance.id == selectedInstanceId ? accent : AppTheme.textMuted.opacity(0.4))
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instance.displayLabel)
                                        .font(.subheadline.weight(.semibold))
                                    Text(instance.url)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .glassCard(tint: instance.id == selectedInstanceId ? accent.opacity(0.1) : nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var readOnlyNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "key.horizontal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(localizer.t.truenasReadOnlyApiKey)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(tint: accent.opacity(0.06))
    }

    private func overview(_ snapshot: TrueNASDashboardSnapshot) -> some View {
        LazyVGrid(columns: columns, spacing: AppTheme.gridSpacing) {
            GlassStatCard(
                title: localizer.t.truenasHealthyPools,
                value: "\(snapshot.healthyPoolCount)/\(snapshot.pools.count)",
                icon: "checkmark.seal.fill",
                iconColor: poolHealthColor(snapshot)
            )
            GlassProgressCard(
                title: localizer.t.truenasStorageUsed,
                value: snapshot.storageUsedPercent,
                icon: "externaldrive.fill",
                color: accent,
                subtitle: "\(Formatters.formatBytes(snapshot.usedStorageBytes)) / \(Formatters.formatBytes(snapshot.totalStorageBytes))"
            )
            GlassStatCard(
                title: localizer.t.truenasShares,
                value: "\(snapshot.shareSummary.totalCount)",
                icon: "folder.fill.badge.gearshape",
                iconColor: accent
            )
            GlassStatCard(
                title: localizer.t.truenasAlerts,
                value: "\(snapshot.alerts.count)",
                icon: snapshot.alerts.isEmpty ? "bell.slash.fill" : "exclamationmark.triangle.fill",
                iconColor: snapshot.alerts.isEmpty ? AppTheme.running : AppTheme.warning
            )
        }
    }

    private func systemCard(_ system: TrueNASSystemInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(localizer.t.truenasSystem, icon: "server.rack")

            VStack(spacing: 10) {
                infoRow(localizer.t.truenasVersion, system.version)
                if let hostname = system.hostname {
                    infoRow(localizer.t.truenasHost, hostname)
                }
                if let product = system.systemProduct {
                    infoRow(localizer.t.truenasProduct, product)
                }
                if let uptime = system.uptime {
                    infoRow(localizer.t.truenasUptime, uptime)
                }
            }
        }
        .padding(16)
        .glassCard(tint: accent.opacity(0.06))
    }

    @ViewBuilder
    private func shareSection(_ summary: TrueNASShareSummary) -> some View {
        if summary.totalCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(localizer.t.truenasShares, icon: "folder.fill.badge.gearshape")

                LazyVGrid(columns: columns, spacing: AppTheme.gridSpacing) {
                    metricTile(title: localizer.t.truenasSMB, value: "\(summary.smbCount)", icon: "desktopcomputer", color: accent)
                    metricTile(title: localizer.t.truenasNFS, value: "\(summary.nfsCount)", icon: "network", color: accent)
                    metricTile(title: localizer.t.truenasISCSI, value: "\(summary.iscsiCount)", icon: "externaldrive.badge.icloud", color: accent)
                    metricTile(title: localizer.t.truenasShares, value: "\(summary.totalCount)", icon: "sum", color: AppTheme.running)
                }
            }
        }
    }

    @ViewBuilder
    private func workloadSection(_ summary: TrueNASWorkloadSummary) -> some View {
        if summary.hasWorkloads {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(localizer.t.truenasWorkloads, icon: "square.stack.3d.up.fill")

                LazyVGrid(columns: columns, spacing: AppTheme.gridSpacing) {
                    GlassStatCard(
                        title: localizer.t.truenasApps,
                        value: "\(summary.appsRunning)/\(summary.appsTotal)",
                        icon: "shippingbox.fill",
                        iconColor: summary.appsRunning == summary.appsTotal ? AppTheme.running : AppTheme.warning
                    )
                    GlassStatCard(
                        title: localizer.t.truenasVirtualMachines,
                        value: "\(summary.virtualMachinesRunning)/\(summary.virtualMachinesTotal)",
                        icon: "cpu.fill",
                        iconColor: summary.virtualMachinesRunning == summary.virtualMachinesTotal ? AppTheme.running : AppTheme.warning
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func serviceSection(_ services: [TrueNASServiceStatus]) -> some View {
        if !services.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(localizer.t.truenasServices, icon: "switch.2")

                GlassStatCard(
                    title: localizer.t.truenasRunningServices,
                    value: "\(services.filter(\.running).count)/\(services.count)",
                    icon: "bolt.horizontal.circle.fill",
                    iconColor: services.contains(where: { !$0.running && $0.enabled }) ? AppTheme.warning : AppTheme.running
                )

                ForEach(Array(services.prefix(8))) { service in
                    HStack(spacing: 12) {
                        Image(systemName: service.running ? "play.circle.fill" : "pause.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(serviceStateColor(service))
                            .frame(width: 30, height: 30)
                            .background(serviceStateColor(service).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(service.enabled ? localizer.t.truenasEnabled : localizer.t.truenasStopped)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                        }

                        Spacer()
                        statusPill(service.running ? localizer.t.truenasRunning : service.state, color: serviceStateColor(service))
                    }
                    .padding(12)
                    .glassCard(tint: serviceStateColor(service).opacity(0.05))
                }
            }
        }
    }

    @ViewBuilder
    private func poolSection(_ pools: [TrueNASPool]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localizer.t.truenasPools, icon: "externaldrive.connected.to.line.below.fill")

            if pools.isEmpty {
                emptyRow(localizer.t.noData, icon: "externaldrive.badge.questionmark")
            } else {
                ForEach(pools) { pool in
                    poolCard(pool)
                }
            }
        }
    }

    private func poolCard(_ pool: TrueNASPool) -> some View {
        let color = pool.healthy ? AppTheme.running : AppTheme.warning
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pool.name)
                        .font(.headline)
                    Text(localizer.t.truenasPoolStatus)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
                statusPill(pool.status, color: color)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(localizer.t.truenasUsed)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                    Text("\(Int(pool.usedPercent.rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
                progressBar(value: pool.usedPercent, color: color)
                Text("\(Formatters.formatBytes(pool.usedBytes)) / \(Formatters.formatBytes(pool.sizeBytes)) • \(localizer.t.truenasAvailable): \(Formatters.formatBytes(pool.availableBytes))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(14)
        .glassCard(tint: color.opacity(0.06))
    }

    @ViewBuilder
    private func diskSection(_ disks: [TrueNASDisk]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localizer.t.truenasDisks, icon: "internaldrive.fill")

            if disks.isEmpty {
                emptyRow(localizer.t.noData, icon: "internaldrive")
            } else {
                ForEach(disks.prefix(12)) { disk in
                    HStack(spacing: 12) {
                        Image(systemName: "internaldrive")
                            .font(.subheadline.bold())
                            .foregroundStyle(accent)
                            .frame(width: 30, height: 30)
                            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(disk.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(diskSubtitle(disk))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(Formatters.formatBytes(disk.sizeBytes))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(12)
                    .glassCard()
                }
            }
        }
    }

    private func emptyRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textMuted)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
        }
        .padding(14)
        .glassCard()
    }

    private func alertSection(_ alerts: [TrueNASAlert]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localizer.t.truenasAlerts, icon: "bell.badge.fill")

            if alerts.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.running)
                    Text(localizer.t.truenasNoAlerts)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(14)
                .glassCard(tint: AppTheme.running.opacity(0.06))
            } else {
                ForEach(alerts.prefix(8)) { alert in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            statusPill(alert.level, color: alertColor(alert.level))
                            Spacer()
                            if let createdAt = alert.createdAt {
                                Text(createdAt)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        Text(alert.message)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .glassCard(tint: alertColor(alert.level).opacity(0.06))
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accent)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(tint: color.opacity(0.05))
    }

    private func progressBar(value: Double, color: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.14))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(min(max(value / 100, 0), 1)))
            }
        }
        .frame(height: 8)
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func poolHealthColor(_ snapshot: TrueNASDashboardSnapshot) -> Color {
        guard !snapshot.pools.isEmpty else { return AppTheme.warning }
        return snapshot.healthyPoolCount == snapshot.pools.count ? AppTheme.running : AppTheme.warning
    }

    private func alertColor(_ level: String) -> Color {
        let normalized = level.lowercased()
        if normalized.contains("critical") || normalized.contains("error") || normalized.contains("alert") {
            return AppTheme.danger
        }
        if normalized.contains("warning") || normalized.contains("warn") {
            return AppTheme.warning
        }
        return accent
    }

    private func serviceStateColor(_ service: TrueNASServiceStatus) -> Color {
        if service.running { return AppTheme.running }
        return service.enabled ? AppTheme.warning : AppTheme.textMuted
    }

    private func diskSubtitle(_ disk: TrueNASDisk) -> String {
        let parts = [disk.model, disk.pool, disk.serial].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        return parts.isEmpty ? localizer.t.noData : parts.joined(separator: " • ")
    }

    private func fetchDashboard() async {
        guard let client = await servicesStore.truenasClient(instanceId: selectedInstanceId) else {
            state = .error(.notConfigured)
            return
        }

        state = .loading
        do {
            snapshot = try await client.getDashboardSnapshot()
            state = .loaded(())
        } catch {
            state = .error(error as? APIError ?? .networkError(error))
        }
    }
}
