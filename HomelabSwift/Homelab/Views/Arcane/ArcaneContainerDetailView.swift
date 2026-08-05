import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ArcaneContainerDetailView: View {
    let instanceId: UUID
    let environmentId: String
    let containerId: String

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer
    @Environment(\.dismiss) private var dismiss

    /// Mutable because container recreate (update) issues a new Docker ID.
    @State private var resolvedContainerId: String
    @State private var detail: ArcaneContainerDetails?
    @State private var logs: String = ""
    @State private var logFilter = ""
    @State private var logAutoScroll = true
    @State private var isLoadingLogs = false
    @State private var isLoading = true
    @State private var isActing = false
    @State private var actingMessage: String?
    @State private var activeTab: Tab = .info
    @State private var actionError: String?
    @State private var showDeleteConfirm = false
    @StateObject private var terminalSession = ArcaneTerminalSession()
    @State private var selectedShell = "/bin/sh"
    @State private var updateSession: ArcaneUpdateProgressSession?
    @State private var showUpdateProgress = false
    @State private var showTerminalFullscreen = false
    @State private var logsTask: URLSessionWebSocketTask?
    @State private var logsSession: URLSession?
    @State private var autoUpdateEnabled = false
    @State private var liveStats: ArcaneContainerStats?
    @State private var statsUnavailable = false

    private let arcaneColor = ServiceType.arcane.colors.primary
    private let quickCommands = ["ls -la", "pwd", "ps aux", "df -h", "top -bn1 | head", "env", "cat /etc/os-release"]
    private let shellOptions = ["/bin/sh", "/bin/bash", "/bin/ash", "/bin/zsh"]
    private let autoUpdateLabelKey = "com.getarcaneapp.arcane.updater"
    @Environment(\.openURL) private var openURL

    init(instanceId: UUID, environmentId: String, containerId: String) {
        self.instanceId = instanceId
        self.environmentId = environmentId
        self.containerId = containerId
        _resolvedContainerId = State(initialValue: containerId)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case info, logs, exec, env
        var id: String { rawValue }

        func title(using tr: Translations) -> String {
            switch self {
            case .info: return tr.arcaneTabInfo
            case .logs: return tr.arcaneTabLogs
            case .exec: return tr.arcaneTabExec
            case .env: return tr.arcaneTabEnv
            }
        }
    }

    private var isRunning: Bool { detail?.isRunning == true }

    var body: some View {
        Group {
            if isLoading && detail == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        headerCard(detail)
                        actionsRow
                        tabBar
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Group {
                        switch activeTab {
                        case .info:
                            ScrollView {
                                infoTab(detail).padding(16)
                            }
                        case .env:
                            ScrollView {
                                envTab(detail).padding(16)
                            }
                        case .logs:
                            logsTab
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .exec:
                            execTab
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView(localizer.t.detailNotFound, systemImage: "exclamationmark.triangle")
            }
        }
        .background(AppTheme.background)
        .navigationTitle(detail?.displayName.isEmpty == false ? detail!.displayName : localizer.t.arcaneContainersTitle)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task { await refresh() }
        .onChange(of: activeTab) { _, tab in
            stopLiveLogs()
            if tab == .logs {
                Task { await loadLogs(follow: true) }
            }
            if tab == .exec {
                Task { await connectTerminalIfNeeded() }
            } else {
                // Keep terminal session alive only on Exec tab to save battery.
                terminalSession.disconnect()
            }
        }
        .onDisappear {
            terminalSession.disconnect()
            stopLiveLogs()
        }
        .alert(localizer.t.error, isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button(localizer.t.confirm, role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .confirmationDialog(localizer.t.delete, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(localizer.t.delete, role: .destructive) {
                Task { await deleteContainer() }
            }
            Button(localizer.t.cancel, role: .cancel) {}
        } message: {
            Text(localizer.t.arcaneForceRemove)
        }
        .sheet(isPresented: $showUpdateProgress) {
            if let updateSession {
                ArcaneUpdateProgressSheet(session: updateSession)
            }
        }
        .fullScreenCover(isPresented: $showTerminalFullscreen) {
            terminalFullscreenView
        }
    }

    // MARK: - Header / actions

    private func headerCard(_ detail: ArcaneContainerDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(detail.displayName)
                    .font(.title3.bold())
                    .lineLimit(1)
                Spacer()
                Text(detail.state?.status ?? "—")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isRunning ? AppTheme.running : AppTheme.stopped)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (isRunning ? AppTheme.running : AppTheme.stopped).opacity(0.12),
                        in: Capsule()
                    )
            }
            Text(detail.image ?? "")
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
                .lineLimit(2)
            if let started = detail.state?.startedAt, !started.isEmpty {
                Text(String(format: localizer.t.arcaneStartedAt, started))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            if let health = detail.state?.health?.status {
                Text(String(format: localizer.t.arcaneHealthLabel, health))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Toggle(isOn: Binding(
                get: { autoUpdateEnabled },
                set: { newValue in
                    Task { await setAutoUpdate(enabled: newValue) }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizer.t.arcaneAutoUpdate)
                        .font(.subheadline.weight(.semibold))
                    Text(localizer.t.arcaneAutoUpdateHint)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .tint(arcaneColor)
            .disabled(isActing)
        }
        .padding(16)
        .glassCard()
    }

    private var actionsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if isRunning {
                        actionButton(localizer.t.actionStop, icon: "stop.fill", color: AppTheme.stopped) {
                            Task { await runAction(.stop) }
                        }
                        actionButton(localizer.t.actionRestart, icon: "arrow.clockwise", color: AppTheme.warning) {
                            Task { await runAction(.restart) }
                        }
                        actionButton(localizer.t.actionPause, icon: "pause.fill", color: AppTheme.info) {
                            Task { await runAction(.pause) }
                        }
                        actionButton(localizer.t.arcaneKill, icon: "xmark.octagon.fill", color: AppTheme.danger) {
                            Task { await runAction(.kill) }
                        }
                    } else {
                        actionButton(localizer.t.actionStart, icon: "play.fill", color: AppTheme.running) {
                            Task { await runAction(.start) }
                        }
                        if detail?.state?.status?.lowercased() == "paused" {
                            actionButton(localizer.t.arcaneUnpause, icon: "play.pause.fill", color: AppTheme.running) {
                                Task { await runAction(.unpause) }
                            }
                        }
                    }
                    actionButton(localizer.t.arcaneUpdate, icon: "arrow.down.circle", color: arcaneColor) {
                        Task { await updateContainer() }
                    }
                    actionButton(localizer.t.arcaneRedeploy, icon: "arrow.triangle.2.circlepath", color: AppTheme.warning) {
                        Task { await redeployContainer() }
                    }
                    actionButton(localizer.t.delete, icon: "trash", color: AppTheme.danger) {
                        showDeleteConfirm = true
                    }
                }
            }
            .disabled(isActing)

            if isActing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(actingMessage ?? "Working…")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    HapticManager.light()
                    activeTab = tab
                } label: {
                    Text(tab.title(using: localizer.translations))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(activeTab == tab ? arcaneColor : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(activeTab == tab ? arcaneColor.opacity(0.12) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard(cornerRadius: 14)
    }

    @ViewBuilder
    private func tabContent(_ detail: ArcaneContainerDetails) -> some View {
        switch activeTab {
        case .info:
            infoTab(detail)
        case .logs:
            logsTab
        case .exec:
            execTab
        case .env:
            envTab(detail)
        }
    }

    private func infoTab(_ detail: ArcaneContainerDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            liveStatsCard

            infoRow("ID", String(detail.id.prefix(12)))
            infoRow(localizer.t.arcaneInfoImage, detail.image ?? "—")
            infoRow(localizer.t.arcaneInfoCreated, detail.created ?? "—")
            if let cmd = detail.config?.cmd, !cmd.isEmpty {
                infoRow(localizer.t.arcaneInfoCmd, cmd.joined(separator: " "))
            }
            if let wd = detail.config?.workingDir, !wd.isEmpty {
                infoRow(localizer.t.arcaneInfoWorkdir, wd)
            }
            if let ports = detail.ports, !ports.isEmpty {
                let text = ports.map { p in
                    let pub = p.publicPort.map(String.init) ?? "-"
                    let priv = p.privatePort.map(String.init) ?? "-"
                    return "\(pub)->\(priv)/\(p.type ?? "tcp")"
                }.joined(separator: ", ")
                infoRow(localizer.t.arcaneInfoPorts, text)
            }
            if let mounts = detail.mounts, !mounts.isEmpty {
                ForEach(mounts) { mount in
                    infoRow(mount.destination ?? "mount", "\(mount.source ?? "") (\(mount.type ?? ""))")
                }
            }
            if let compose = detail.composeInfo {
                infoRow(localizer.t.arcaneInfoCompose, "\(compose.projectName ?? "") / \(compose.serviceName ?? "")")
            }
        }
        .padding(14)
        .glassCard()
        .task(id: "\(resolvedContainerId)-\(isRunning)") {
            await pollLiveStats()
        }
    }

    @ViewBuilder
    private var liveStatsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.t.arcaneStatsTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)
            if statsUnavailable {
                Text(localizer.t.arcaneStatsUnavailable)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else if let liveStats {
                HStack(spacing: 12) {
                    if let cpu = liveStats.cpuPercent {
                        statPill(localizer.t.arcaneStatsCPU, String(format: "%.1f%%", cpu), AppTheme.info)
                    }
                    if let mem = liveStats.memoryUsage {
                        let memText: String = {
                            if let pct = liveStats.memoryPercent {
                                return "\(Formatters.formatBytes(Double(mem))) (\(String(format: "%.0f%%", pct)))"
                            }
                            return Formatters.formatBytes(Double(mem))
                        }()
                        statPill(localizer.t.arcaneStatsMemory, memText, AppTheme.running)
                    }
                }
            } else if isRunning {
                ProgressView().controlSize(.small)
            } else {
                Text(localizer.t.noData)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statPill(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @MainActor
    private func pollLiveStats() async {
        guard isRunning else {
            liveStats = nil
            statsUnavailable = false
            return
        }
        while !Task.isCancelled {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
            do {
                liveStats = try await client.getContainerStats(id: resolvedContainerId, environmentId: environmentId)
                statsUnavailable = false
            } catch {
                // Endpoint may not exist on older Arcane builds.
                if liveStats == nil { statsUnavailable = true }
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    private var filteredLogs: String {
        let q = logFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return logs }
        return logs
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(q) }
            .joined(separator: "\n")
    }

    private var logsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizer.t.detailLogs)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
                if isLoadingLogs {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                Button {
                    logAutoScroll.toggle()
                } label: {
                    Image(systemName: logAutoScroll ? "arrow.down.to.line" : "pause.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(logAutoScroll ? localizer.t.arcaneLogAutoScrollOn : localizer.t.arcaneLogPaused)

                if !logs.isEmpty {
                    ShareLink(item: logs) {
                        Label(localizer.t.arcaneLogExport, systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await loadLogs(follow: true) }
                } label: {
                    Label(localizer.t.refresh, systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(AppTheme.textMuted)
                TextField(localizer.t.arcaneLogFilter, text: $logFilter)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ScrollViewReader { proxy in
                ScrollView {
                    let display: String = {
                        if filteredLogs.isEmpty {
                            if isLoadingLogs { return localizer.t.arcaneLogLoading }
                            if logs.isEmpty { return localizer.t.arcaneLogEmpty }
                            return localizer.t.noData
                        }
                        return filteredLogs
                    }()
                    Text(display)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(filteredLogs.isEmpty ? AppTheme.textMuted : Color(white: 0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("log-bottom")
                }
                .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
                .padding(10)
                .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: logs.count) { _, _ in
                    guard logAutoScroll else { return }
                    withAnimation { proxy.scrollTo("log-bottom", anchor: .bottom) }
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity)
        .glassCard()
    }

    private var execTab: some View {
        terminalChrome(minHeight: 220, showFullscreenButton: true)
            .padding(14)
            .frame(maxHeight: .infinity)
            .glassCard()
    }

    private var terminalFullscreenView: some View {
        NavigationStack {
            terminalChrome(minHeight: 480, showFullscreenButton: false)
                .padding(16)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle(localizer.t.arcaneTabExec)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizer.t.close) { showTerminalFullscreen = false }
                    }
                }
                .task {
                    await connectTerminalIfNeeded()
                }
        }
    }

    /// Interactive terminal powered by open-source SwiftTerm (xterm/VT100).
    /// Type directly in the terminal — no line-buffered TextField.
    private func terminalChrome(minHeight: CGFloat, showFullscreenButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(localizer.t.arcaneTabExec)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer(minLength: 0)
                Circle()
                    .fill(terminalSession.isConnected ? AppTheme.running : AppTheme.stopped)
                    .frame(width: 8, height: 8)
                Text(terminalSession.isConnected
                     ? localizer.t.arcaneTerminalConnected
                     : localizer.t.arcaneTerminalDisconnected)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)

                Menu {
                    ForEach(shellOptions, id: \.self) { shell in
                        Button {
                            selectedShell = shell
                            Task { await reconnectTerminal() }
                        } label: {
                            if selectedShell == shell {
                                Label(shell, systemImage: "checkmark")
                            } else {
                                Text(shell)
                            }
                        }
                    }
                } label: {
                    Text((selectedShell as NSString).lastPathComponent)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.14), in: Capsule())
                }

                Button(terminalSession.isConnected
                       ? localizer.t.arcaneTerminalDisconnect
                       : localizer.t.arcaneTerminalConnect) {
                    if terminalSession.isConnected {
                        terminalSession.disconnect()
                    } else {
                        Task { await connectTerminalIfNeeded() }
                    }
                }
                .font(.caption.weight(.semibold))

                Button(localizer.t.arcaneClear) {
                    terminalSession.clearScreen()
                }
                .font(.caption.weight(.semibold))

                if showFullscreenButton {
                    Button {
                        showTerminalFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizer.t.arcaneTerminalFullscreen)
                }
            }

            ArcaneSwiftTermView(session: terminalSession, fontSize: showFullscreenButton ? 12.5 : 14) { url in
                openURL(url)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
            )

            // Soft function keys for common control sequences (SwiftTerm keyboard still handles typing).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    termKey("Esc") { terminalSession.sendText("\u{1b}") }
                    termKey("Tab") { terminalSession.sendText("\t") }
                    termKey("Ctrl+C") { terminalSession.sendText("\u{0003}") }
                    termKey("Ctrl+D") { terminalSession.sendText("\u{0004}") }
                    termKey("Ctrl+L") { terminalSession.sendText("\u{000c}") }
                    termKey("↑") { terminalSession.sendText("\u{1b}[A") }
                    termKey("↓") { terminalSession.sendText("\u{1b}[B") }
                    termKey("←") { terminalSession.sendText("\u{1b}[D") }
                    termKey("→") { terminalSession.sendText("\u{1b}[C") }
                    termKey("Home") { terminalSession.sendText("\u{1b}[H") }
                    termKey("End") { terminalSession.sendText("\u{1b}[F") }
                    termKey("Paste") { pasteFromClipboard() }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(quickCommands, id: \.self) { cmd in
                        Button(cmd) {
                            // Inject as if typed, then Enter — works with interactive shells / prompts.
                            terminalSession.sendText(cmd + "\r")
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(arcaneColor.opacity(0.12), in: Capsule())
                        .buttonStyle(.plain)
                        .disabled(!terminalSession.isConnected)
                    }
                }
            }

            if let statusMessage = terminalSession.statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.danger)
            } else {
                Text(localizer.t.arcaneTerminalInteractiveHint)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    private func termKey(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption2.weight(.bold).monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .buttonStyle(.plain)
            .disabled(!terminalSession.isConnected && title != "Paste")
    }

    private func envTab(_ detail: ArcaneContainerDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let env = detail.config?.env, !env.isEmpty {
                ForEach(env, id: \.self) { line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            } else {
                Text(localizer.t.noData)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(14)
        .glassCard()
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    // MARK: - Networking

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else {
                actionError = APIError.notConfigured.localizedDescription
                return
            }
            do {
                detail = try await client.getContainerDetails(id: resolvedContainerId, environmentId: environmentId)
            } catch {
                // After update/redeploy the Docker ID changes — resolve by name.
                if let name = detail?.displayName, !name.isEmpty,
                   let newId = try await client.findContainerId(
                       named: name,
                       environmentId: environmentId
                   ) {
                    resolvedContainerId = newId
                    detail = try await client.getContainerDetails(id: newId, environmentId: environmentId)
                } else {
                    throw error
                }
            }
            syncAutoUpdateFromLabels()
            if activeTab == .logs {
                await loadLogs(using: client, follow: true)
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func syncAutoUpdateFromLabels() {
        // Arcane label policy: com.getarcaneapp.arcane.updater=true|false
        let raw = detail?.labels?[autoUpdateLabelKey]?.lowercased()
        autoUpdateEnabled = raw == "true" || raw == "1" || raw == "enabled"
    }

    private func setAutoUpdate(enabled: Bool) async {
        let previous = autoUpdateEnabled
        autoUpdateEnabled = enabled
        isActing = true
        actingMessage = enabled ? "Enabling auto-update…" : "Disabling auto-update…"
        defer {
            isActing = false
            actingMessage = nil
        }
        do {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else {
                autoUpdateEnabled = previous
                return
            }
            try await client.setAutoUpdate(
                id: resolvedContainerId,
                enabled: enabled,
                environmentId: environmentId
            )
            HapticManager.success()
            await refresh()
        } catch {
            autoUpdateEnabled = previous
            HapticManager.error()
            actionError = error.localizedDescription
        }
    }

    /// Load container logs via Arcane WebSocket only (no REST).
    /// Official UI uses a single `follow=true&tail=N` stream — historical lines come first, then live.
    ///
    /// Important: never `await task.receive()` on the MainActor — a stuck receive freezes the UI
    /// spinner timeout and looks like an infinite loading state.
    @MainActor
    private func loadLogs(using existing: ArcaneAPIClient? = nil, follow: Bool = true) async {
        stopLiveLogs()
        isLoadingLogs = true
        logs = ""

        let client: ArcaneAPIClient
        if let existing {
            client = existing
        } else if let c = await servicesStore.arcaneClient(instanceId: instanceId) {
            client = c
        } else {
            logs = "/* Arcane client unavailable */"
            isLoadingLogs = false
            return
        }

        // Always open the live stream (includes tail history). `follow` kept for call-site compatibility.
        _ = follow
        startLiveLogs(client: client, tail: 300)
    }

    /// Fire-and-forget stream. Receive runs off the main actor; UI updates hop back.
    @MainActor
    private func startLiveLogs(client: ArcaneAPIClient, tail: Int = 300) {
        let containerId = resolvedContainerId
        let envId = environmentId

        Task {
            do {
                let url = try await client.logsWebSocketURL(
                    containerId: containerId,
                    environmentId: envId,
                    tail: tail,
                    follow: true
                )
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                for (k, v) in await client.currentAuthHeaders() {
                    request.setValue(v, forHTTPHeaderField: k)
                }
                let session = URLSession(
                    configuration: .default,
                    delegate: InsecureTrustDelegate(),
                    delegateQueue: nil
                )
                let task = session.webSocketTask(with: request)

                await MainActor.run {
                    self.logsSession = session
                    self.logsTask = task
                }
                task.resume()

                // Spinner safety net (must not share the MainActor with a blocked receive).
                let loadingTask = task
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    guard self.isLoadingLogs, self.logsTask === loadingTask else { return }
                    self.isLoadingLogs = false
                    if self.logs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.logs = "/* \(self.localizer.t.arcaneLogTimeoutHint) */\n"
                    }
                }

                await self.receiveLogsLoop(task)
            } catch {
                await MainActor.run {
                    self.isLoadingLogs = false
                    self.logs = "/* \(String(format: self.localizer.t.arcaneLogFailedFormat, error.localizedDescription)) */\n"
                }
            }
        }
    }

    /// Runs off the main actor so `receive()` cannot freeze the UI.
    private func receiveLogsLoop(_ task: URLSessionWebSocketTask) async {
        while true {
            let stillActive = await MainActor.run { logsTask === task }
            guard stillActive else { break }

            do {
                let message = try await task.receive()
                let text: String
                switch message {
                case .string(let s): text = s
                case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
                @unknown default: text = ""
                }
                guard !text.isEmpty else { continue }

                let lines = ArcaneTextSanitizer.parseLogWSPayload(text)
                guard !lines.isEmpty else { continue }

                await MainActor.run {
                    if isLoadingLogs { isLoadingLogs = false }
                    if logs.count > 120_000 {
                        logs = String(logs.suffix(80_000))
                    }
                    if logs.hasPrefix("/*") {
                        logs = ""
                    }
                    for line in lines {
                        logs += line
                        if !line.hasSuffix("\n") { logs += "\n" }
                    }
                }
            } catch {
                await MainActor.run {
                    if isLoadingLogs { isLoadingLogs = false }
                    if logs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        logs = "/* log stream closed: \(error.localizedDescription) */\n"
                    } else if !logs.hasSuffix("\n") {
                        logs += "\n"
                    }
                    if logsTask === task {
                        logsTask = nil
                        logsSession?.invalidateAndCancel()
                        logsSession = nil
                    }
                }
                break
            }
        }
        await MainActor.run {
            if isLoadingLogs { isLoadingLogs = false }
        }
    }

    @MainActor
    private func stopLiveLogs() {
        logsTask?.cancel(with: .goingAway, reason: nil)
        logsSession?.invalidateAndCancel()
        logsTask = nil
        logsSession = nil
        if isLoadingLogs { isLoadingLogs = false }
    }

    private func runAction(_ action: ArcaneContainerAction) async {
        isActing = true
        actingMessage = actionStatusMessage(for: action)
        defer {
            isActing = false
            actingMessage = nil
        }
        do {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
            try await client.containerAction(id: resolvedContainerId, action: action, environmentId: environmentId)
            HapticManager.success()
            await refresh()
        } catch {
            HapticManager.error()
            actionError = error.localizedDescription
        }
    }

    private func actionStatusMessage(for action: ArcaneContainerAction) -> String {
        switch action {
        case .start: return "Starting container…"
        case .stop: return "Stopping container…"
        case .restart: return "Restarting container…"
        case .kill: return "Killing container…"
        case .pause: return "Pausing container…"
        case .unpause: return "Unpausing container…"
        }
    }

    private func updateContainer() async {
        isActing = true
        actingMessage = "Updating… pull/recreate can take a few minutes"
        defer {
            isActing = false
            actingMessage = nil
        }
        guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else {
            actionError = "Arcane client unavailable"
            return
        }

        let targetId = resolvedContainerId
        let targetName = detail?.displayName ?? String(targetId.prefix(12))
        let session = ArcaneUpdateProgressSession(
            title: "Update",
            subtitle: targetName,
            lines: [],
            isRunning: true
        )
        updateSession = session
        showUpdateProgress = true

        let outcome = await ArcaneUpdateProgressRunner.run(
            session: session,
            client: client,
            environmentId: environmentId,
            resourceIdHint: targetId,
            resourceNameHint: targetName
        ) {
            try await client.updateContainer(id: targetId, environmentId: environmentId)
        }

        switch outcome {
        case .success(let result):
            if result.didFail {
                HapticManager.error()
            } else {
                HapticManager.success()
            }
            // Re-resolve ID by name — recreate always mints a new container ID.
            if let newId = try? await client.findContainerId(named: targetName, environmentId: environmentId) {
                resolvedContainerId = newId
            }
            await refresh()
        case .failure(let error):
            HapticManager.error()
            actionError = error.localizedDescription
            // Still try to re-bind if the container was recreated before the error surfaced.
            if let newId = try? await client.findContainerId(named: targetName, environmentId: environmentId) {
                resolvedContainerId = newId
                await refresh()
            }
        }
    }

    private func redeployContainer() async {
        isActing = true
        actingMessage = "Redeploying container…"
        defer {
            isActing = false
            actingMessage = nil
        }
        do {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
            let targetName = detail?.displayName ?? ""
            try await client.redeployContainer(id: resolvedContainerId, environmentId: environmentId)
            if !targetName.isEmpty,
               let newId = try? await client.findContainerId(named: targetName, environmentId: environmentId) {
                resolvedContainerId = newId
            }
            HapticManager.success()
            await refresh()
        } catch {
            HapticManager.error()
            actionError = error.localizedDescription
        }
    }

    private func deleteContainer() async {
        isActing = true
        actingMessage = "Deleting container…"
        defer {
            isActing = false
            actingMessage = nil
        }
        do {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
            try await client.deleteContainer(id: resolvedContainerId, environmentId: environmentId, force: true)
            HapticManager.success()
            dismiss()
        } catch {
            HapticManager.error()
            actionError = error.localizedDescription
        }
    }

    // MARK: - Terminal (SwiftTerm + Arcane WebSocket PTY)

    @MainActor
    private func connectTerminalIfNeeded() async {
        guard !terminalSession.isConnected else { return }
        guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else {
            terminalSession.feedLocal("\r\n\u{1b}[31m[error] \(localizer.t.arcaneClientUnavailable)\u{1b}[0m\r\n")
            return
        }
        await terminalSession.connect(
            client: client,
            containerId: resolvedContainerId,
            environmentId: environmentId,
            shell: selectedShell
        )
    }

    @MainActor
    private func reconnectTerminal() async {
        terminalSession.disconnect(notifyUI: false)
        terminalSession.clearScreen()
        await connectTerminalIfNeeded()
    }

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let text = UIPasteboard.general.string, !text.isEmpty {
            if terminalSession.isConnected {
                terminalSession.sendText(text)
            }
        }
        #endif
    }
}
