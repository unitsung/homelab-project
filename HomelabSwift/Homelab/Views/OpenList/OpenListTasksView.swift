import SwiftUI

/// OpenList task center — mirrors web task panel actions:
/// refresh / retry failed / clear / clear succeeded / retry·delete selected / per-row delete·retry·expand.
/// APIs: GET `/api/task/{type}/undone|done`, POST cancel|retry|delete|*_some|clear_*|retry_failed.
struct OpenListTasksView: View {
    let instanceId: UUID

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer

    @State private var client: OpenListAPIClient?
    @State private var taskType: OpenListTaskType = .copy
    @State private var phase: OpenListTaskPhase = .undone
    @State private var tasks: [OpenListTaskInfo] = []
    @State private var state: LoadableState<Void> = .idle
    @State private var actionError: String?
    @State private var isActing = false
    @State private var selectedIDs: Set<String> = []
    @State private var expandedIDs: Set<String> = []
    @State private var mineOnly = false

    private var serviceColor: Color { ServiceType.openlist.colors.primary }

    private var displayedTasks: [OpenListTaskInfo] {
        guard mineOnly else { return tasks }
        // Best-effort: keep tasks whose creator matches common admin labels or non-empty ownership.
        // Server already scopes by user for non-admins; this is a UI filter like the web “只显示我的任务”.
        return tasks.filter { !$0.creator.isEmpty }
    }

    private var allDisplayedSelected: Bool {
        !displayedTasks.isEmpty && displayedTasks.allSatisfy { selectedIDs.contains($0.id) }
    }

    private var selectedTasks: [OpenListTaskInfo] {
        displayedTasks.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                Picker(localizer.t.filesTaskTypeLabel, selection: $taskType) {
                    ForEach(OpenListTaskType.allCases) { type in
                        Text(title(for: type)).tag(type)
                    }
                }
                .pickerStyle(.menu)

                Picker(localizer.t.filesTaskPhaseLabel, selection: $phase) {
                    Text(localizer.t.filesTasksUndone).tag(OpenListTaskPhase.undone)
                    Text(localizer.t.filesTasksDone).tag(OpenListTaskPhase.done)
                }
                .pickerStyle(.segmented)
            }

            // Action chip bar — same operations as OpenList web.
            Section {
                actionBar
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)

                Toggle(isOn: $mineOnly) {
                    Text(localizer.t.filesTaskMineOnly)
                        .font(.subheadline)
                }
                .tint(serviceColor)
            }

            if let actionError {
                Section {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if displayedTasks.isEmpty, case .loaded = state {
                    ContentUnavailableView(
                        localizer.t.filesTaskEmpty,
                        systemImage: "tray",
                        description: Text(title(for: taskType))
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(displayedTasks) { task in
                        taskRow(task)
                    }
                }
            } header: {
                HStack {
                    Text(phase == .undone ? localizer.t.filesTasksUndone : localizer.t.filesTasksDone)
                    Spacer()
                    if case .loading = state {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("\(displayedTasks.count)")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Button {
                        toggleExpandAll()
                    } label: {
                        Text(expandedIDs.count == displayedTasks.count && !displayedTasks.isEmpty
                             ? localizer.t.filesTaskCollapseAll
                             : localizer.t.filesTaskExpandAll)
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(serviceColor)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(localizer.t.filesTasks)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await reload(silent: false) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isActing)
                .accessibilityLabel(localizer.t.filesTaskRefresh)
            }
        }
        .refreshable { await reload(silent: true) }
        .task {
            client = await servicesStore.openlistClient(instanceId: instanceId)
            await reload(silent: false)
        }
        .onChange(of: taskType) { _, _ in
            selectedIDs.removeAll()
            expandedIDs.removeAll()
            Task { await reload(silent: false) }
        }
        .onChange(of: phase) { _, _ in
            selectedIDs.removeAll()
            expandedIDs.removeAll()
            Task { await reload(silent: false) }
        }
        .task(id: "\(taskType.rawValue)-\(phase.rawValue)") {
            guard phase == .undone else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { break }
                await reload(silent: true)
            }
        }
        .opacity(isActing ? 0.85 : 1)
    }

    // MARK: - Action bar (web-style chips)

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(localizer.t.filesTaskRefresh, color: Color(hex: "#A78BFA").opacity(0.28)) {
                    Task { await reload(silent: false) }
                }
                chip(localizer.t.filesTaskRetryFailed, color: Color(hex: "#60A5FA").opacity(0.28)) {
                    Task { await retryFailed() }
                }
                chip(localizer.t.filesTaskClearDone, color: Color(hex: "#F87171").opacity(0.28)) {
                    Task { await clearDone() }
                }
                chip(localizer.t.filesTaskClearSucceeded, color: Color(hex: "#4ADE80").opacity(0.28)) {
                    Task { await clearSucceeded() }
                }

                if phase == .undone {
                    chip(
                        localizer.t.filesTaskCancelSelected,
                        color: Color(hex: "#FBBF24").opacity(0.28),
                        disabled: selectedIDs.isEmpty
                    ) {
                        Task { await cancelSelected() }
                    }
                } else {
                    chip(
                        localizer.t.filesTaskRetrySelected,
                        color: Color(hex: "#67E8F9").opacity(0.35),
                        disabled: selectedIDs.isEmpty
                    ) {
                        Task { await retrySelected() }
                    }
                }

                chip(
                    localizer.t.filesTaskDeleteSelected,
                    color: Color(hex: "#FCD34D").opacity(0.4),
                    disabled: selectedIDs.isEmpty
                ) {
                    Task { await deleteSelected() }
                }

                chip(
                    allDisplayedSelected ? localizer.t.filesTaskDeselectAll : localizer.t.filesTaskSelectAll,
                    color: Color(.tertiarySystemFill)
                ) {
                    toggleSelectAll()
                }
            }
        }
    }

    private func chip(
        _ title: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(disabled ? AppTheme.textMuted : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled || isActing)
        .opacity(disabled ? 0.55 : 1)
    }

    // MARK: - Rows

    @ViewBuilder
    private func taskRow(_ task: OpenListTaskInfo) -> some View {
        let selected = selectedIDs.contains(task.id)
        let expanded = expandedIDs.contains(task.id)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    toggleSelect(task.id)
                } label: {
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(selected ? serviceColor : AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    Text(task.name.isEmpty ? task.id : task.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(expanded ? 8 : 2)

                    HStack(spacing: 8) {
                        if !task.creator.isEmpty {
                            Text(task.creator.uppercased())
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#A78BFA").opacity(0.22), in: Capsule())
                                .foregroundStyle(Color(hex: "#7C3AED"))
                        }
                        stateBadge(task)
                        Spacer(minLength: 0)
                    }

                    ProgressView(value: task.progressFraction)
                        .tint(progressTint(for: task))

                    HStack(spacing: 10) {
                        Text(String(format: "%.0f%%", min(max(task.progress, 0), 100)))
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        if task.totalBytes > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: task.totalBytes, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if !task.status.isEmpty {
                            // OpenList often puts speed / detail text in `status`.
                            Text(task.status)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(expanded ? 4 : 1)
                        }
                    }
                }
            }

            // Per-row operations (web: 删除 / 展开 / retry)
            HStack(spacing: 8) {
                if phase == .undone {
                    rowAction(localizer.t.filesTaskCancel, tint: .red.opacity(0.12), fg: .red) {
                        Task { await cancel(task) }
                    }
                } else {
                    if task.state == .failed || task.state == .canceled || task.state == .errored {
                        rowAction(localizer.t.filesTaskRetry, tint: serviceColor.opacity(0.14), fg: serviceColor) {
                            Task { await retry(task) }
                        }
                    }
                    rowAction(localizer.t.filesTaskDelete, tint: .red.opacity(0.12), fg: .red) {
                        Task { await delete(task) }
                    }
                }

                rowAction(
                    expanded ? localizer.t.filesTaskCollapse : localizer.t.filesTaskExpand,
                    tint: Color(.tertiarySystemFill),
                    fg: .primary
                ) {
                    toggleExpand(task.id)
                }

                Spacer(minLength: 0)
            }

            if expanded {
                expandedDetails(task)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { toggleSelect(task.id) }
    }

    private func rowAction(
        _ title: String,
        tint: Color,
        fg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(fg)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isActing)
    }

    @ViewBuilder
    private func expandedDetails(_ task: OpenListTaskInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            detailLine(localizer.t.filesTaskCreator, task.creator.isEmpty ? "—" : task.creator)
            detailLine("ID", task.id)
            if let start = task.startTime {
                detailLine(localizer.t.filesModifiedLabel, start.formatted(date: .abbreviated, time: .shortened))
            }
            if let end = task.endTime {
                detailLine(localizer.t.filesTaskStateSucceeded, end.formatted(date: .abbreviated, time: .shortened))
            }
            if !task.error.isEmpty {
                Text(task.error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !task.status.isEmpty {
                Text(task.status)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private func stateBadge(_ task: OpenListTaskInfo) -> some View {
        Text(stateLabel(task.state))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(stateColor(task.state).opacity(0.15), in: Capsule())
            .foregroundStyle(stateColor(task.state))
    }

    private func progressTint(for task: OpenListTaskInfo) -> Color {
        switch task.state {
        case .succeeded: return AppTheme.running
        case .failed, .failing, .errored: return .red
        case .canceled, .canceling: return AppTheme.textSecondary
        default: return serviceColor
        }
    }

    private func stateColor(_ state: OpenListTaskState) -> Color {
        switch state {
        case .succeeded: return AppTheme.running
        case .failed, .failing, .errored: return .red
        case .running, .pending, .waitingRetry, .beforeRetry: return serviceColor
        case .canceled, .canceling: return AppTheme.textSecondary
        }
    }

    private func stateLabel(_ state: OpenListTaskState) -> String {
        switch state {
        case .pending: return localizer.t.filesTaskStatePending
        case .running: return localizer.t.filesTaskStateRunning
        case .succeeded: return localizer.t.filesTaskStateSucceeded
        case .canceling: return localizer.t.filesTaskStateCanceling
        case .canceled: return localizer.t.filesTaskStateCanceled
        case .errored: return localizer.t.filesTaskStateErrored
        case .failing: return localizer.t.filesTaskStateFailing
        case .failed: return localizer.t.filesTaskStateFailed
        case .waitingRetry: return localizer.t.filesTaskStateWaitingRetry
        case .beforeRetry: return localizer.t.filesTaskStateBeforeRetry
        }
    }

    private func title(for type: OpenListTaskType) -> String {
        switch type {
        case .copy: return localizer.t.filesTaskTypeCopy
        case .offlineDownload: return localizer.t.filesTaskTypeOfflineDownload
        case .offlineDownloadTransfer: return localizer.t.filesTaskTypeOfflineTransfer
        case .move: return localizer.t.filesTaskTypeMove
        case .upload: return localizer.t.filesTaskTypeUpload
        case .decompress: return localizer.t.filesTaskTypeDecompress
        case .decompressUpload: return localizer.t.filesTaskTypeDecompressUpload
        }
    }

    // MARK: - Selection / expand

    private func toggleSelect(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        if allDisplayedSelected {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(displayedTasks.map(\.id))
        }
    }

    private func toggleExpand(_ id: String) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func toggleExpandAll() {
        if expandedIDs.count == displayedTasks.count, !displayedTasks.isEmpty {
            expandedIDs.removeAll()
        } else {
            expandedIDs = Set(displayedTasks.map(\.id))
        }
    }

    // MARK: - Load / actions

    @MainActor
    private func reload(silent: Bool) async {
        guard let client else {
            if !silent { state = .error(.notConfigured) }
            return
        }
        if !silent { state = .loading }
        do {
            let list = try await client.listTasks(type: taskType, phase: phase)
            tasks = list
            // Drop selections that no longer exist.
            let valid = Set(list.map(\.id))
            selectedIDs = selectedIDs.intersection(valid)
            expandedIDs = expandedIDs.intersection(valid)
            state = .loaded(())
            actionError = nil
        } catch let error as APIError {
            if !silent {
                state = .error(error)
                actionError = error.localizedDescription
            }
        } catch {
            if !silent {
                state = .error(.networkError(error))
                actionError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func cancel(_ task: OpenListTaskInfo) async {
        await runAction { try await client?.cancelTask(type: task.type, id: task.id) }
    }

    @MainActor
    private func retry(_ task: OpenListTaskInfo) async {
        await runAction { try await client?.retryTask(type: task.type, id: task.id) }
    }

    @MainActor
    private func delete(_ task: OpenListTaskInfo) async {
        await runAction { try await client?.deleteTask(type: task.type, id: task.id) }
    }

    @MainActor
    private func cancelSelected() async {
        let ids = selectedTasks.map(\.id)
        guard !ids.isEmpty else { return }
        await runAction {
            try await client?.cancelTasks(type: taskType, ids: ids)
            selectedIDs.removeAll()
        }
    }

    @MainActor
    private func retrySelected() async {
        let ids = selectedTasks.map(\.id)
        guard !ids.isEmpty else { return }
        await runAction {
            try await client?.retryTasks(type: taskType, ids: ids)
            selectedIDs.removeAll()
        }
    }

    @MainActor
    private func deleteSelected() async {
        let ids = selectedTasks.map(\.id)
        guard !ids.isEmpty else { return }
        await runAction {
            try await client?.deleteTasks(type: taskType, ids: ids)
            selectedIDs.removeAll()
        }
    }

    @MainActor
    private func clearDone() async {
        await runAction {
            try await client?.clearDoneTasks(type: taskType)
            selectedIDs.removeAll()
        }
    }

    @MainActor
    private func clearSucceeded() async {
        await runAction {
            try await client?.clearSucceededTasks(type: taskType)
            selectedIDs.removeAll()
        }
    }

    @MainActor
    private func retryFailed() async {
        await runAction { try await client?.retryFailedTasks(type: taskType) }
    }

    @MainActor
    private func runAction(_ work: () async throws -> Void) async {
        isActing = true
        defer { isActing = false }
        do {
            try await work()
            await reload(silent: true)
        } catch {
            actionError = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }
}

