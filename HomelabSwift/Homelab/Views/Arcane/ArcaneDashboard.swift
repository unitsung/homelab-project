import SwiftUI

struct ArcaneDashboard: View {
    let instanceId: UUID

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer

    @State private var selectedInstanceId: UUID
    @State private var environments: [ArcaneEnvironment] = []
    @State private var selectedEnvironment: ArcaneEnvironment?
    @State private var containers: [ArcaneContainer] = []
    @State private var statusCounts: ArcaneStatusCounts?
    @State private var dockerInfo: ArcaneDockerInfo?
    @State private var updateSummary: ArcaneImageUpdateSummary?
    @State private var imageUsage: ArcaneImageUsageCounts?
    @State private var state: LoadableState<Void> = .idle
    @State private var actionInProgress: Set<String> = []
    @State private var selectionMode = false
    @State private var selectedIds: Set<String> = []
    @State private var query = ""
    @State private var filter: ContainerFilter = .all
    @State private var bannerMessage: String?
    @State private var bannerTask: Task<Void, Never>?
    @State private var confirmStopAll = false
    @State private var confirmStartAll = false
    @State private var confirmBatchUpdate = false
    @State private var confirmBatchDelete = false
    @State private var confirmPruneDangling = false
    @State private var confirmPruneUnusedImages = false
    @State private var confirmPruneVolumes = false
    @State private var confirmSystemPrune = false
    @State private var isBatchRunning = false
    @State private var updateSession: ArcaneUpdateProgressSession?
    @State private var showUpdateProgress = false
    @State private var showImagesSheet = false
    /// Server-side `updates=has_update` result (authoritative when local flags are missing).
    @State private var serverUpdateContainers: [ArcaneContainer] = []
    @State private var isLoadingUpdatesFilter = false
    @State private var pendingDeleteId: String?

    private let arcaneColor = ServiceType.arcane.colors.primary

    enum ContainerFilter: String, CaseIterable, Identifiable {
        case all, running, stopped, updates
        var id: String { rawValue }
    }

    private func filterTitle(_ item: ContainerFilter) -> String {
        switch item {
        case .all: return localizer.t.arcaneFilterAll
        case .running: return localizer.t.arcaneFilterRunning
        case .stopped: return localizer.t.arcaneFilterStopped
        case .updates: return localizer.t.arcaneFilterUpdates
        }
    }

    init(instanceId: UUID) {
        self.instanceId = instanceId
        _selectedInstanceId = State(initialValue: instanceId)
    }

    private var serverUpdateIds: Set<String> {
        Set(serverUpdateContainers.map(\.id))
    }

    private func containerNeedsUpdate(_ container: ArcaneContainer) -> Bool {
        container.hasUpdate || serverUpdateIds.contains(container.id)
    }

    private var containersWithUpdates: [ArcaneContainer] {
        // Prefer items from the full list so navigation/env stay consistent.
        let fromMain = containers.filter(containerNeedsUpdate)
        if !fromMain.isEmpty { return fromMain }
        // Server returned containers not present in the main page (pagination/stale).
        return serverUpdateContainers
    }

    /// Count of **containers** with available updates (matches the Updates list).
    /// Do not fall back to image-level summary — unused images would inflate the badge
    /// while the list stays empty and looks like an error.
    private var updateCount: Int {
        containersWithUpdates.count
    }

    private var filteredContainers: [ArcaneContainer] {
        var list: [ArcaneContainer]
        switch filter {
        case .all:
            list = containers
        case .running:
            list = containers.filter(\.isRunning)
        case .stopped:
            list = containers.filter { !$0.isRunning }
        case .updates:
            list = containersWithUpdates
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.displayName.lowercased().contains(q)
                    || $0.image.lowercased().contains(q)
                    || $0.status.lowercased().contains(q)
            }
        }
        return list
    }

    var body: some View {
        ServiceDashboardLayout(
            serviceType: .arcane,
            instanceId: selectedInstanceId,
            state: state,
            onRefresh: fetchAll
        ) {
            instancePicker

            if environments.count > 1 {
                environmentPicker
            }

            if let env = selectedEnvironment {
                environmentInfoSection(env)
            }

            if let info = dockerInfo {
                dockerHostSection(info)
            }

            // Keep feedback near the top so long container lists never hide it.
            if let bannerMessage {
                bannerView(bannerMessage)
            }

            bulkActionsSection
            containerStatsSection
            filterBar
            containerListSection
        }
        .navigationTitle(ServiceType.arcane.displayName)
        .onChange(of: bannerMessage) { _, newValue in
            bannerTask?.cancel()
            guard let newValue else { return }
            let isError = Self.bannerLooksLikeError(newValue)
            bannerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: isError ? 4_000_000_000 : 2_800_000_000)
                guard !Task.isCancelled else { return }
                if bannerMessage == newValue {
                    bannerMessage = nil
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selectionMode ? localizer.t.done : localizer.t.actionEdit) {
                    selectionMode.toggle()
                    if !selectionMode { selectedIds.removeAll() }
                }
            }
        }
        .navigationDestination(for: ArcaneRoute.self) { route in
            switch route {
            case .containers(let instanceId, let environmentId):
                ArcaneContainerListView(instanceId: instanceId, environmentId: environmentId)
            case .containerDetail(let instanceId, let environmentId, let containerId):
                ArcaneContainerDetailView(
                    instanceId: instanceId,
                    environmentId: environmentId,
                    containerId: containerId
                )
            }
        }
        // Centered alerts (more reliable than bottom action sheets on notched iPhones).
        .alert(localizer.t.arcaneConfirmStopAll, isPresented: $confirmStopAll) {
            Button(localizer.t.arcaneStopAll, role: .destructive) {
                Task { await runStopAll() }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        }
        .alert(localizer.t.arcaneConfirmStartAll, isPresented: $confirmStartAll) {
            Button(localizer.t.arcaneStartAll) {
                Task { await runStartAll() }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        }
        .alert(localizer.t.arcaneConfirmUpdateSelected, isPresented: $confirmBatchUpdate) {
            Button(localizer.t.arcaneUpdate) {
                Task { await runBatchUpdate() }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        }
        .alert(localizer.t.arcaneConfirmDeleteSelected, isPresented: $confirmBatchDelete) {
            Button(localizer.t.delete, role: .destructive) {
                Task { await runBatchDelete() }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        }
        .alert(localizer.t.arcaneConfirmPruneDangling, isPresented: $confirmPruneDangling) {
            Button(localizer.t.arcanePruneDangling, role: .destructive) {
                Task { await runPruneImages(danglingOnly: true) }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        } message: {
            Text(localizer.t.arcanePruneDanglingHint)
        }
        .alert(localizer.t.arcaneConfirmPruneUnusedImages, isPresented: $confirmPruneUnusedImages) {
            Button(localizer.t.arcanePruneUnusedImages, role: .destructive) {
                Task { await runPruneImages(danglingOnly: false) }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        } message: {
            Text(localizer.t.arcanePruneUnusedImagesHint)
        }
        .alert(localizer.t.arcaneConfirmPruneVolumes, isPresented: $confirmPruneVolumes) {
            Button(localizer.t.arcanePruneVolumes, role: .destructive) {
                Task { await runPruneVolumes() }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        } message: {
            Text(localizer.t.arcanePruneVolumesHint)
        }
        .alert(localizer.t.arcaneConfirmSystemPrune, isPresented: $confirmSystemPrune) {
            Button(localizer.t.arcaneSystemPrune, role: .destructive) {
                Task { await runSystemPrune() }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        } message: {
            Text(localizer.t.arcaneSystemPruneHint)
        }
        .alert(localizer.t.delete, isPresented: Binding(
            get: { pendingDeleteId != nil },
            set: { if !$0 { pendingDeleteId = nil } }
        )) {
            Button(localizer.t.delete, role: .destructive) {
                if let id = pendingDeleteId {
                    pendingDeleteId = nil
                    Task { await deleteOne(id) }
                }
            }
            Button(localizer.t.cancel, role: .cancel) {
                pendingDeleteId = nil
            }
        } message: {
            Text(localizer.t.arcaneForceRemove)
        }
        .sheet(isPresented: $showUpdateProgress) {
            if let updateSession {
                ArcaneUpdateProgressSheet(session: updateSession)
            }
        }
        .sheet(isPresented: $showImagesSheet) {
            ArcaneImagesSheet(
                instanceId: selectedInstanceId,
                environmentId: selectedEnvironment?.id ?? ArcaneEnvironment.localId
            )
            .environment(localizer)
            .environment(servicesStore)
        }
        .task(id: selectedInstanceId) { await fetchAll() }
        .onChange(of: filter) { _, newValue in
            if newValue == .updates {
                Task { await ensureUpdateContainersLoaded() }
            }
        }
        .onChange(of: selectedEnvironment?.id) { _, _ in
            serverUpdateContainers = []
        }
    }

    // MARK: - Instance / environment

    private var instancePicker: some View {
        let instances = servicesStore.instances(for: .arcane)
        return Group {
            if instances.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localizer.t.dashboardInstances.sentenceCased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)
                    ForEach(instances) { instance in
                        Button {
                            HapticManager.light()
                            selectedInstanceId = instance.id
                            servicesStore.setPreferredInstance(id: instance.id, for: .arcane)
                            resetData()
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(instance.id == selectedInstanceId ? arcaneColor : AppTheme.textMuted.opacity(0.4))
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instance.displayLabel)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(instance.url)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .glassCard(tint: instance.id == selectedInstanceId ? arcaneColor.opacity(0.1) : nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var environmentPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.t.portainerEndpoints.sentenceCased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)
            ForEach(environments) { env in
                Button {
                    HapticManager.light()
                    selectedEnvironment = env
                    Task { await fetchContainers() }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(env.isOnline ? AppTheme.running : AppTheme.stopped)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(env.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(env.apiUrl ?? env.id)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        if selectedEnvironment?.id == env.id {
                            Text(localizer.t.portainerActive)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(arcaneColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(arcaneColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(14)
                    .glassCard(tint: selectedEnvironment?.id == env.id ? arcaneColor.opacity(0.1) : nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func environmentInfoSection(_ env: ArcaneEnvironment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.body)
                .foregroundStyle(arcaneColor)
                .frame(width: 40, height: 40)
                .background(arcaneColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(env.displayName)
                    .font(.body.weight(.bold))
                HStack(spacing: 4) {
                    Circle()
                        .fill(env.isOnline ? AppTheme.running : AppTheme.stopped)
                        .frame(width: 6, height: 6)
                    Text(env.isOnline ? localizer.t.portainerOnline : localizer.t.portainerOffline)
                        .font(.caption)
                        .foregroundStyle(env.isOnline ? AppTheme.running : AppTheme.stopped)
                }
            }
            Spacer()
        }
        .padding(14)
        .glassCard()
    }

    private func dockerHostSection(_ info: ArcaneDockerInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.t.arcaneDockerHost)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                hostStat(icon: "cpu", label: localizer.t.arcaneCPUs, value: "\(info.ncpu ?? 0)", color: arcaneColor)
                hostStat(
                    icon: "memorychip",
                    label: localizer.t.overviewMemoryLabel,
                    value: Formatters.formatBytes(Double(info.memTotal ?? 0)),
                    color: AppTheme.info
                )
                hostStat(icon: "photo", label: localizer.t.arcaneImages, value: "\(info.images ?? 0)", color: AppTheme.paused)
                hostStat(icon: "shippingbox", label: localizer.t.arcaneVersion, value: info.serverVersion ?? "—", color: AppTheme.running)
            }

            if let name = info.name, !name.isEmpty {
                Text("\(name) · \(info.driver ?? "—") · \(info.operatingSystem ?? "")")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(2)
            }
        }
    }

    private func hostStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.body.bold())
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard()
    }

    // MARK: - Bulk actions

    private var bulkActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizer.t.arcaneActions)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    actionChip(localizer.t.arcaneStartAll, icon: "play.fill", color: AppTheme.running) { confirmStartAll = true }
                    actionChip(localizer.t.arcaneStopAll, icon: "stop.fill", color: AppTheme.stopped) { confirmStopAll = true }
                    actionChip(localizer.t.arcaneStartStopped, icon: "play.circle", color: AppTheme.info) {
                        Task { await runStartStopped() }
                    }
                    actionChip(localizer.t.arcaneRunUpdater, icon: "arrow.triangle.2.circlepath", color: arcaneColor) {
                        Task { await runUpdaterAll() }
                    }
                    actionChip(localizer.t.arcaneCheckUpdates, icon: "magnifyingglass.circle", color: AppTheme.info) {
                        Task { await runCheckAllImageUpdates() }
                    }
                    actionChip(localizer.t.arcanePruneDangling, icon: "trash.circle", color: AppTheme.warning) {
                        confirmPruneDangling = true
                    }
                    actionChip(localizer.t.arcanePruneUnusedImages, icon: "photo.on.rectangle.angled", color: AppTheme.danger) {
                        confirmPruneUnusedImages = true
                    }
                    actionChip(localizer.t.arcanePruneVolumes, icon: "externaldrive.badge.xmark", color: AppTheme.danger) {
                        confirmPruneVolumes = true
                    }
                    actionChip(localizer.t.arcaneSystemPrune, icon: "washer", color: AppTheme.danger) {
                        confirmSystemPrune = true
                    }
                    if selectionMode {
                        actionChip(localizer.t.arcaneUpdateSelected, icon: "arrow.down.circle", color: AppTheme.warning, disabled: selectedIds.isEmpty) {
                            confirmBatchUpdate = true
                        }
                        actionChip(localizer.t.arcaneStopSelected, icon: "stop.circle", color: AppTheme.stopped, disabled: selectedIds.isEmpty) {
                            Task { await runSelectedAction(.stop) }
                        }
                        actionChip(localizer.t.arcaneStartSelected, icon: "play.circle.fill", color: AppTheme.running, disabled: selectedIds.isEmpty) {
                            Task { await runSelectedAction(.start) }
                        }
                        actionChip(localizer.t.arcaneRestartSelected, icon: "arrow.clockwise", color: AppTheme.warning, disabled: selectedIds.isEmpty) {
                            Task { await runSelectedAction(.restart) }
                        }
                        actionChip(localizer.t.arcaneDeleteSelected, icon: "trash", color: AppTheme.danger, disabled: selectedIds.isEmpty) {
                            confirmBatchDelete = true
                        }
                    }
                }
            }

            if updateCount > 0 {
                Button {
                    filter = .updates
                    Task { await ensureUpdateContainersLoaded() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text(String(format: localizer.t.arcaneUpdatesAvailableFormat, updateCount))
                            .multilineTextAlignment(.leading)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if let imageUsage {
                Button {
                    showImagesSheet = true
                } label: {
                    HStack {
                        Text(
                            String(
                                format: localizer.t.arcaneImagesUsageFormat,
                                imageUsage.total,
                                imageUsage.unused,
                                Formatters.formatBytes(Double(imageUsage.totalSize))
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text(localizer.t.arcaneImagesTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(arcaneColor)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(arcaneColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if isBatchRunning {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func actionChip(
        _ title: String,
        icon: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.glass)
        .tint(disabled ? Color.secondary : color)
        .disabled(disabled || isBatchRunning)
    }

    // MARK: - Stats / filters / list

    private var containerStatsSection: some View {
        let running = statusCounts?.running ?? containers.filter(\.isRunning).count
        let stopped = statusCounts?.stopped ?? containers.filter { !$0.isRunning }.count
        let total = statusCounts?.total ?? containers.count

        return VStack(alignment: .leading, spacing: 12) {
            Text(localizer.t.portainerContainers.sentenceCased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)

            HStack(spacing: 8) {
                miniStat(localizer.t.portainerTotal, total, AppTheme.info) {
                    filter = .all
                }
                miniStat(localizer.t.portainerRunning, running, AppTheme.running) {
                    filter = .running
                }
                miniStat(localizer.t.portainerStopped, stopped, AppTheme.stopped) {
                    filter = .stopped
                }
                miniStat(localizer.t.arcaneFilterUpdates, updateCount, AppTheme.warning) {
                    filter = .updates
                    Task { await ensureUpdateContainersLoaded() }
                }
            }
        }
    }

    private func miniStat(_ label: String, _ value: Int, _ color: Color, action: (() -> Void)? = nil) -> some View {
        Button {
            HapticManager.light()
            action?()
        } label: {
            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.title3.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 14, tint: color.opacity(0.08))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textMuted)
                TextField(localizer.t.filesSearchPlaceholder, text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(12)
            .glassCard()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ContainerFilter.allCases) { item in
                        Button {
                            filter = item
                        } label: {
                            HStack(spacing: 4) {
                                Text(filterTitle(item))
                                if item == .updates, updateCount > 0 {
                                    Text("\(updateCount)")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(
                                            Capsule().fill(filter == item ? Color.white.opacity(0.25) : AppTheme.warning.opacity(0.2))
                                        )
                                }
                                if item == .updates, isLoadingUpdatesFilter {
                                    ProgressView().controlSize(.mini)
                                }
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .glassChipStyle(selected: filter == item, tint: arcaneColor)
                    }
                }
            }
        }
    }

    private var containerListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if filter == .updates, isLoadingUpdatesFilter, filteredContainers.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(localizer.t.arcaneLoadingUpdates)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassCard()
            } else if filteredContainers.isEmpty {
                // Neutral empty state (no error-style copy when Updates is 0).
                Text(localizer.t.noData)
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassCard()
            } else {
                ForEach(filteredContainers) { container in
                    containerRow(container)
                }
            }
        }
    }

    private func containerRow(_ container: ArcaneContainer) -> some View {
        let selected = selectedIds.contains(container.id)
        return HStack(spacing: 12) {
            if selectionMode {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? arcaneColor : AppTheme.textMuted)
                    .onTapGesture {
                        toggleSelection(container.id)
                    }
            }

            NavigationLink(
                value: ArcaneRoute.containerDetail(
                    instanceId: selectedInstanceId,
                    environmentId: selectedEnvironment?.id ?? ArcaneEnvironment.localId,
                    containerId: container.id
                )
            ) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor(for: container.state))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(container.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if containerNeedsUpdate(container) {
                                Text(localizer.t.arcaneUpdateBadge)
                                    .font(.caption2.bold())
                                    .foregroundStyle(AppTheme.warning)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .glassCard(cornerRadius: 20, tint: AppTheme.warning.opacity(0.2))
                            }
                        }
                        Text(container.image)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textMuted)
                            .lineLimit(1)
                        Text(container.status)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if !selectionMode {
                        Menu {
                            if container.isRunning {
                                Button { performAction(.stop, on: container.id) } label: {
                                    Label(localizer.t.actionStop, systemImage: "stop.fill")
                                }
                                Button { performAction(.restart, on: container.id) } label: {
                                    Label(localizer.t.actionRestart, systemImage: "arrow.clockwise")
                                }
                                Button { performAction(.pause, on: container.id) } label: {
                                    Label(localizer.t.actionPause, systemImage: "pause.fill")
                                }
                            } else {
                                Button { performAction(.start, on: container.id) } label: {
                                    Label(localizer.t.actionStart, systemImage: "play.fill")
                                }
                            }
                            Button { Task { await updateOne(container.id) } } label: {
                                Label(localizer.t.arcaneUpdate, systemImage: "arrow.down.circle")
                            }
                            Button { Task { await redeployOne(container.id) } } label: {
                                Label(localizer.t.arcaneRedeploy, systemImage: "arrow.triangle.2.circlepath")
                            }
                            Button(role: .destructive) {
                                pendingDeleteId = container.id
                            } label: {
                                Label(localizer.t.delete, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(arcaneColor)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .opacity(actionInProgress.contains(container.id) ? 0.5 : 1)
        .glassCard(tint: selected ? arcaneColor.opacity(0.08) : nil)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectionMode { toggleSelection(container.id) }
        }
    }

    // MARK: - Data

    private func resetData() {
        environments = []
        selectedEnvironment = nil
        containers = []
        statusCounts = nil
        dockerInfo = nil
        updateSummary = nil
        imageUsage = nil
        serverUpdateContainers = []
        selectedIds.removeAll()
    }

    private func fetchAll() async {
        state = .loading
        do {
            guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
                state = .error(.notConfigured)
                return
            }
            environments = try await client.getEnvironments()
            if selectedEnvironment == nil {
                selectedEnvironment = environments.first(where: { $0.id == ArcaneEnvironment.localId })
                    ?? environments.first
            } else if let current = selectedEnvironment,
                      let refreshed = environments.first(where: { $0.id == current.id }) {
                selectedEnvironment = refreshed
            }
            await fetchContainers()
            if let envId = selectedEnvironment?.id {
                dockerInfo = try? await client.getDockerInfo(environmentId: envId)
                updateSummary = try? await client.getImageUpdateSummary(environmentId: envId)
                imageUsage = try? await client.getImageUsageCounts(environmentId: envId)
            }
            state = .loaded(())
        } catch let apiError as APIError {
            state = .error(apiError)
        } catch {
            state = .error(.custom(error.localizedDescription))
        }
    }

    private func fetchContainers() async {
        guard let env = selectedEnvironment else { return }
        do {
            guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
            isLoadingUpdatesFilter = true
            defer { isLoadingUpdatesFilter = false }
            async let list = client.getContainers(environmentId: env.id)
            async let counts = client.getContainerStatusCounts(environmentId: env.id)
            // Multi-path match (has_update / by-refs / images) — not just summary count.
            async let updateList = client.getContainersNeedingUpdate(environmentId: env.id)
            containers = try await list
            statusCounts = try? await counts
            serverUpdateContainers = (try? await updateList) ?? []
        } catch let apiError as APIError {
            if containers.isEmpty { state = .error(apiError) }
        } catch {
            if containers.isEmpty { state = .error(.custom(error.localizedDescription)) }
        }
    }

    /// Ensures we have a server-side update list when the Updates filter is used.
    private func ensureUpdateContainersLoaded() async {
        guard let env = selectedEnvironment else { return }
        if !serverUpdateContainers.isEmpty { return }
        if containers.contains(where: \.hasUpdate) {
            serverUpdateContainers = containers.filter(\.hasUpdate)
            return
        }

        isLoadingUpdatesFilter = true
        defer { isLoadingUpdatesFilter = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        do {
            serverUpdateContainers = try await client.getContainersNeedingUpdate(environmentId: env.id)
        } catch {
            // Keep existing list; empty state shows the hint.
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }

    private func envId() -> String {
        selectedEnvironment?.id ?? ArcaneEnvironment.localId
    }

    private func performAction(_ action: ArcaneContainerAction, on id: String) {
        Task {
            guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
            actionInProgress.insert(id)
            defer { actionInProgress.remove(id) }
            do {
                try await client.containerAction(id: id, action: action, environmentId: envId())
                HapticManager.light()
                bannerMessage = String(format: localizer.t.arcaneActionOkFormat, action.rawValue)
            } catch {
                bannerMessage = error.localizedDescription
            }
            await fetchContainers()
        }
    }

    private func updateOne(_ id: String) async {
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
            bannerMessage = localizer.t.arcaneClientUnavailable
            return
        }
        actionInProgress.insert(id)
        defer { actionInProgress.remove(id) }

        let name = containers.first(where: { $0.id == id })?.displayName ?? String(id.prefix(12))
        let session = ArcaneUpdateProgressSession(
            title: localizer.t.arcaneUpdate,
            subtitle: name,
            lines: [],
            isRunning: true
        )
        updateSession = session
        showUpdateProgress = true
        bannerMessage = String(format: localizer.t.arcaneUpdatingFormat, name)

        let outcome = await ArcaneUpdateProgressRunner.run(
            session: session,
            client: client,
            environmentId: envId(),
            resourceIdHint: id,
            resourceNameHint: name
        ) {
            try await client.updateContainer(id: id, environmentId: envId())
        }

        switch outcome {
        case .success(let result):
            bannerMessage = result.userFacingSummary
            if result.didFail { HapticManager.error() } else { HapticManager.success() }
        case .failure(let error):
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func redeployOne(_ id: String) async {
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        actionInProgress.insert(id)
        defer { actionInProgress.remove(id) }
        do {
            try await client.redeployContainer(id: id, environmentId: envId())
            bannerMessage = localizer.t.arcaneRedeployed
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func deleteOne(_ id: String) async {
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        actionInProgress.insert(id)
        defer { actionInProgress.remove(id) }
        do {
            try await client.deleteContainer(id: id, environmentId: envId(), force: true)
            bannerMessage = localizer.t.arcaneDeleted
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runStartAll() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        do {
            _ = try await client.startAllContainers(environmentId: envId())
            bannerMessage = localizer.t.arcaneStartAllRequested
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runStartStopped() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        do {
            _ = try await client.startStoppedContainers(environmentId: envId())
            bannerMessage = localizer.t.arcaneStartStoppedRequested
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runStopAll() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        do {
            _ = try await client.stopAllContainers(environmentId: envId())
            bannerMessage = localizer.t.arcaneStopAllRequested
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runUpdaterAll() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
            bannerMessage = localizer.t.arcaneClientUnavailable
            return
        }
        let session = ArcaneUpdateProgressSession(
            title: localizer.t.arcaneUpdater,
            subtitle: localizer.t.arcaneAllPendingUpdates,
            lines: [],
            isRunning: true
        )
        updateSession = session
        showUpdateProgress = true
        bannerMessage = localizer.t.arcaneRunningUpdater

        let outcome = await ArcaneUpdateProgressRunner.run(
            session: session,
            client: client,
            environmentId: envId(),
            resourceNameHint: "Auto update"
        ) {
            try await client.runUpdater(environmentId: envId())
        }

        switch outcome {
        case .success(let result):
            bannerMessage = result.userFacingSummary
            if result.didFail { HapticManager.error() } else { HapticManager.success() }
        case .failure(let error):
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runCheckAllImageUpdates() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
            bannerMessage = localizer.t.arcaneClientUnavailable
            return
        }
        bannerMessage = localizer.t.arcaneCheckingUpdates
        do {
            _ = try await client.checkAllImageUpdates(environmentId: envId())
            updateSummary = try? await client.getImageUpdateSummary(environmentId: envId())
            imageUsage = try? await client.getImageUsageCounts(environmentId: envId())
            serverUpdateContainers = (try? await client.getContainersNeedingUpdate(environmentId: envId())) ?? []
            // No "Checked N images…" footer — results show in the Updates count / list.
            bannerMessage = nil
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runPruneImages(danglingOnly: Bool) async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
            bannerMessage = localizer.t.arcaneClientUnavailable
            return
        }
        bannerMessage = danglingOnly ? localizer.t.arcanePruningDangling : localizer.t.arcanePruningUnusedImages
        do {
            let report = try await client.pruneImages(environmentId: envId(), danglingOnly: danglingOnly)
            bannerMessage = report.userFacingSummary
            imageUsage = try? await client.getImageUsageCounts(environmentId: envId())
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
    }

    private func runPruneVolumes() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
            bannerMessage = localizer.t.arcaneClientUnavailable
            return
        }
        bannerMessage = localizer.t.arcanePruningVolumes
        do {
            let report = try await client.pruneVolumes(environmentId: envId())
            bannerMessage = report.userFacingSummary
            HapticManager.success()
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
    }

    private func runSystemPrune() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
            bannerMessage = localizer.t.arcaneClientUnavailable
            return
        }
        bannerMessage = localizer.t.arcaneRunningSystemPrune
        do {
            let report = try await client.pruneSystem(
                environmentId: envId(),
                images: true,
                volumes: false,
                networks: true,
                containers: false,
                buildCache: false,
                imageMode: "unused"
            )
            bannerMessage = report.userFacingSummary
            imageUsage = try? await client.getImageUsageCounts(environmentId: envId())
            if report.success == false {
                HapticManager.error()
            } else {
                HapticManager.success()
            }
        } catch {
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
    }

    private func runBatchUpdate() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else {
            bannerMessage = localizer.t.arcaneClientUnavailable
            return
        }
        let ids = Array(selectedIds)
        let session = ArcaneUpdateProgressSession(
            title: localizer.t.arcaneUpdate,
            subtitle: String(format: localizer.t.arcaneBatchUpdatingFormat, ids.count),
            lines: [],
            isRunning: true
        )
        updateSession = session
        showUpdateProgress = true
        bannerMessage = String(format: localizer.t.arcaneBatchUpdatingFormat, ids.count)

        let env = envId()
        let outcome = await ArcaneUpdateProgressRunner.run(
            session: session,
            client: client,
            environmentId: env,
            resourceNameHint: localizer.t.arcaneAllPendingUpdates
        ) {
            do {
                return try await client.runUpdater(environmentId: env, resourceIds: ids, forceUpdate: false)
            } catch {
                // Fallback: per-container update (same long-timeout path)
                var ok = 0
                var fail = 0
                var lastError: String?
                for id in ids {
                    do {
                        let result = try await client.updateContainer(id: id, environmentId: env)
                        if result.didApplyUpdate { ok += 1 }
                        if result.didFail {
                            fail += 1
                            lastError = result.userFacingSummary
                        }
                    } catch {
                        fail += 1
                        lastError = error.localizedDescription
                    }
                }
                if ok == 0, fail > 0 {
                    throw APIError.custom(lastError ?? "Updated 0/\(ids.count)")
                }
                return ArcaneUpdaterResult(
                    success: fail == 0,
                    checked: ids.count,
                    updated: ok,
                    restarted: 0,
                    skipped: max(0, ids.count - ok - fail),
                    failed: fail,
                    startTime: nil,
                    endTime: nil,
                    duration: nil,
                    items: nil,
                    activityId: nil
                )
            }
        }

        switch outcome {
        case .success(let result):
            bannerMessage = result.userFacingSummary
            if result.didFail { HapticManager.error() } else { HapticManager.success() }
        case .failure(let error):
            bannerMessage = error.localizedDescription
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runSelectedAction(_ action: ArcaneContainerAction) async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        var ok = 0
        var fail = 0
        for id in selectedIds {
            do {
                try await client.containerAction(id: id, action: action, environmentId: envId())
                ok += 1
            } catch {
                fail += 1
            }
        }
        let actionTitle = localizedActionTitle(action)
        if fail == 0 {
            bannerMessage = String(format: localizer.t.arcaneBatchAllOkFormat, actionTitle, ok)
            HapticManager.success()
        } else {
            bannerMessage = String(format: localizer.t.arcaneBatchResultFormat, actionTitle, ok, fail)
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func runBatchDelete() async {
        isBatchRunning = true
        defer { isBatchRunning = false }
        guard let client = await servicesStore.arcaneClient(instanceId: selectedInstanceId) else { return }
        var ok = 0
        var fail = 0
        for id in selectedIds {
            do {
                try await client.deleteContainer(id: id, environmentId: envId(), force: true)
                ok += 1
            } catch {
                fail += 1
            }
        }
        selectedIds.removeAll()
        if fail == 0 {
            bannerMessage = String(format: localizer.t.arcaneBatchAllOkFormat, localizer.t.delete, ok)
            HapticManager.success()
        } else {
            bannerMessage = String(format: localizer.t.arcaneBatchResultFormat, localizer.t.delete, ok, fail)
            HapticManager.error()
        }
        await fetchContainers()
    }

    private func localizedActionTitle(_ action: ArcaneContainerAction) -> String {
        switch action {
        case .start: return localizer.t.actionStart
        case .stop: return localizer.t.actionStop
        case .restart: return localizer.t.actionRestart
        case .pause: return localizer.t.actionPause
        case .unpause: return localizer.t.arcaneUnpause
        case .kill: return localizer.t.arcaneKill
        }
    }

    private func statusColor(for state: String) -> Color {
        switch state.lowercased() {
        case "running": return AppTheme.running
        case "exited", "dead", "created": return .gray
        case "paused": return AppTheme.paused
        default: return AppTheme.warning
        }
    }

    private func bannerView(_ text: String) -> some View {
        let isError = Self.bannerLooksLikeError(text)
        let tint = isError ? AppTheme.danger : AppTheme.running
        return HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(tint)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 10, tint: tint.opacity(0.2))
    }

    private static func bannerLooksLikeError(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("fail")
            || lower.contains("error")
            || lower.contains("unavailable")
            || text.contains("失败")
            || text.contains("错误")
            || text.contains("不可用")
    }
}

// MARK: - Routes

enum ArcaneRoute: Hashable {
    case containers(instanceId: UUID, environmentId: String)
    case containerDetail(instanceId: UUID, environmentId: String, containerId: String)
}

// MARK: - Full list (legacy route → dashboard)

struct ArcaneContainerListView: View {
    let instanceId: UUID
    let environmentId: String

    var body: some View {
        // Prefer the full dashboard (env picker + filters + bulk actions).
        ArcaneDashboard(instanceId: instanceId)
    }
}

// MARK: - Images browser

private struct ArcaneImagesSheet: View {
    let instanceId: UUID
    let environmentId: String

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer
    @Environment(\.dismiss) private var dismiss

    @State private var images: [ArcaneImageSummary] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var updatesOnly = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(localizer.t.loading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorText {
                    ContentUnavailableView(errorText, systemImage: "exclamationmark.triangle")
                } else if images.isEmpty {
                    ContentUnavailableView(localizer.t.arcaneImageNoData, systemImage: "photo.stack")
                } else {
                    List(images) { image in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(image.primaryTag)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                Spacer()
                                if image.hasUpdate {
                                    Text(localizer.t.arcaneUpdateBadge)
                                        .font(.caption2.bold())
                                        .foregroundStyle(AppTheme.warning)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .glassCard(cornerRadius: 20, tint: AppTheme.warning.opacity(0.2))
                                }
                            }
                            HStack {
                                Text(Formatters.formatBytes(Double(image.size ?? 0)))
                                Spacer()
                                Text(image.inUse == true ? localizer.t.arcaneImageInUse : localizer.t.arcaneImageUnused)
                                    .foregroundStyle(image.inUse == true ? AppTheme.running : AppTheme.textMuted)
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            if !image.usedContainerNames.isEmpty {
                                Text(image.usedContainerNames.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textMuted)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(localizer.t.arcaneImagesTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker(localizer.t.arcaneImagesTitle, selection: $updatesOnly) {
                        Text(localizer.t.arcaneImagesAll).tag(false)
                        Text(localizer.t.arcaneImagesWithUpdates).tag(true)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            .task(id: updatesOnly) { await load() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else {
            errorText = localizer.t.arcaneClientUnavailable
            return
        }
        do {
            images = try await client.getImages(environmentId: environmentId, updatesOnly: updatesOnly)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
            images = []
        }
    }
}
