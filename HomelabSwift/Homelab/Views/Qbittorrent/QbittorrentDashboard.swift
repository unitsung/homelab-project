import SwiftUI

struct QbittorrentDashboard: View {
    let instanceId: UUID
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var client: QbittorrentAPIClient?
    @State private var transferInfo: QbittorrentTransferInfo?
    @State private var torrents: [QbittorrentTorrent] = []
    @State private var state: LoadableState<Void> = .idle
    @State private var selectedFilter: QbittorrentFilter = .all
    @State private var searchQuery: String = ""
    @State private var isFetching = false
    @State private var isViewVisible = false
    @State private var isRunningTorrentAction = false
    @State private var actionMessage: String?
    @State private var showAddSheet = false
    @State private var addURLsText = ""
    @State private var addValidationError: String?
    @State private var pendingDeleteWithFilesHash: String?
    private var arr: ArrStrings { localizer.arr }
    
    // Keep transfer stats closer to real time while refreshing the heavier torrent list less often.
    private let transferTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()
    private let listTimer = Timer.publish(every: 24, on: .main, in: .common).autoconnect()

    var body: some View {
        ServiceDashboardLayout(
            serviceType: .qbittorrent,
            instanceId: instanceId,
            state: state,
            onRefresh: { await fetchData(silent: false, includeTorrents: true) }
        ) {
            if let transferInfo {
                transferStatsSection(transferInfo: transferInfo)
            }

            if let actionMessage {
                actionMessageBanner(actionMessage)
            }

            filterSection
            
            if !displayedTorrents.isEmpty {
                torrentsListSection
            } else if case .loaded = state {
                Text(localizer.t.noData)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            }
        }
        .task {
            self.client = await servicesStore.qbittorrentClient(instanceId: instanceId)
            await fetchData(silent: false, includeTorrents: true)
        }
        .onAppear { isViewVisible = true }
        .onDisappear { isViewVisible = false }
        .onReceive(transferTimer) { _ in
            guard scenePhase == .active, isViewVisible else { return }
            Task { await fetchData(silent: true, includeTorrents: false) }
        }
        .onReceive(listTimer) { _ in
            guard scenePhase == .active, isViewVisible else { return }
            Task { await fetchData(silent: true, includeTorrents: true) }
        }
        .sheet(isPresented: $showAddSheet) {
            addTorrentSheet
        }
        .confirmationDialog(
            arr.deleteWithDataConfirmTitle,
            isPresented: Binding(
                get: { pendingDeleteWithFilesHash != nil },
                set: { if !$0 { pendingDeleteWithFilesHash = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(arr.deleteWithData, role: .destructive) {
                guard let hash = pendingDeleteWithFilesHash else { return }
                pendingDeleteWithFilesHash = nil
                Task {
                    await performTorrentAction(successMessage: arr.torrentAndDataDeleted) {
                        try await requireClient().deleteTorrent(hash: hash, deleteFiles: true)
                    }
                }
            }
            Button(localizer.t.cancel, role: .cancel) {
                pendingDeleteWithFilesHash = nil
            }
        } message: {
            Text(arr.deleteWithDataConfirmMessage)
        }
    }

    private var addTorrentSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(arr.addTorrentPlaceholder)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)

                TextEditor(text: $addURLsText)
                    .font(.body.monospaced())
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(AppTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                if let addValidationError {
                    Text(addValidationError)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(AppTheme.background)
            .navigationTitle(arr.addTorrentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.cancel) {
                        showAddSheet = false
                        addURLsText = ""
                        addValidationError = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(arr.addTorrentSubmit) {
                        Task { await submitAddTorrents() }
                    }
                    .disabled(isRunningTorrentAction)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @MainActor
    private func fetchData(silent: Bool, includeTorrents: Bool) async {
        guard servicesStore.instance(id: instanceId) != nil else {
            if !silent { state = .error(.notConfigured) }
            return
        }
        guard let client else { return }
        if isFetching { return }
        if silent {
            guard isViewVisible, servicesStore.reachability(for: instanceId) != false else { return }
        }

        isFetching = true
        defer { isFetching = false }

        if !silent { state = .loading }
        do {
            self.transferInfo = try await client.getTransferInfo()
            if includeTorrents {
                self.torrents = try await client.getTorrents(filter: "all")
            }
            state = .loaded(())
        } catch let apiError as APIError {
            if silent {
                await servicesStore.checkReachability(for: instanceId)
            } else {
                state = .error(apiError)
            }
        } catch {
            if silent {
                await servicesStore.checkReachability(for: instanceId)
            } else {
                state = .error(.custom(error.localizedDescription))
            }
        }
    }
    
    private func transferStatsSection(transferInfo: QbittorrentTransferInfo) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(arr.connection)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(transferInfo.connection_status.capitalized)
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(transferInfo.connection_status.lowercased() == "connected" ? AppTheme.running.opacity(0.15) : AppTheme.warning.opacity(0.15), in: Capsule())
                    .foregroundStyle(transferInfo.connection_status.lowercased() == "connected" ? AppTheme.running : AppTheme.warning)
            }

            HStack(spacing: 16) {
                statCard(
                    title: arr.download,
                    value: Formatters.formatBytes(Double(transferInfo.dl_info_speed)) + "/s",
                    icon: "arrow.down.circle.fill",
                    color: AppTheme.running
                )
                
                statCard(
                    title: arr.upload,
                    value: Formatters.formatBytes(Double(transferInfo.up_info_speed)) + "/s",
                    icon: "arrow.up.circle.fill",
                    color: AppTheme.info
                )
            }

            HStack(spacing: 12) {
                secondaryStatCard(
                    title: arr.dhtLabel,
                    value: "\(transferInfo.dht_nodes ?? 0)",
                    icon: "point.3.connected.trianglepath.dotted",
                    color: AppTheme.info
                )
                secondaryStatCard(
                    title: arr.altSpeedLabel,
                    value: transferInfo.use_alt_speed_limits == true ? localizer.t.yes : localizer.t.no,
                    icon: transferInfo.use_alt_speed_limits == true ? "tortoise.fill" : "gauge.with.needle",
                    color: transferInfo.use_alt_speed_limits == true ? AppTheme.warning : AppTheme.running
                )
            }

            if let freeDisk = transferInfo.free_space_on_disk {
                secondaryStatCard(
                    title: arr.diskFreeLabel,
                    value: Formatters.formatBytes(Double(freeDisk)),
                    icon: "internaldrive.fill",
                    color: AppTheme.primary,
                    emphasized: true
                )
            }
        }
    }

    private func actionMessageBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.running)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.running)
            Spacer()
        }
        .padding(12)
        .background(AppTheme.running.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var filterSection: some View {
        VStack(spacing: 10) {
            Picker(arr.filterAll, selection: $selectedFilter) {
                ForEach(QbittorrentFilter.allCases, id: \.self) { filter in
                    Text(filterTitle(filter)).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textMuted)
                TextField(arr.searchTorrents, text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 8)
    }

    private var displayedTorrents: [QbittorrentTorrent] {
        let filtered = torrents.filter { torrent in
            let matchesFilter: Bool = switch selectedFilter {
            case .all:
                true
            case .downloading:
                torrent.isDownloading || torrent.isUploading || torrent.isChecking
            case .completed:
                torrent.progress >= 0.999 && !torrent.isDownloading && !torrent.isChecking && !torrent.isError
            case .paused:
                torrent.isPaused
            }
            guard matchesFilter else { return false }

            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return torrent.name.localizedCaseInsensitiveContains(query) ||
                torrent.hash.localizedCaseInsensitiveContains(query)
        }

        return filtered.sorted { lhs, rhs in
            let lhsRank = statusRank(lhs)
            let rhsRank = statusRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.progress != rhs.progress { return lhs.progress > rhs.progress }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func statusRank(_ torrent: QbittorrentTorrent) -> Int {
        if torrent.isError { return 0 }
        if torrent.isDownloading { return 1 }
        if torrent.isUploading { return 2 }
        if torrent.isChecking { return 3 }
        if torrent.isPaused { return 4 }
        return 5
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(value)
                .font(.headline.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private func secondaryStatCard(
        title: String,
        value: String,
        icon: String,
        color: Color,
        emphasized: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(value)
                    .font(emphasized ? .subheadline.weight(.heavy) : .subheadline.weight(.semibold))
                    .foregroundStyle(emphasized ? .primary : color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .leading)
        .padding(14)
        .glassCard(tint: color.opacity(0.08))
    }
    
    private var torrentsListSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text(arr.torrents)
                    .font(.title2.bold())
                Spacer()
                Button {
                    addURLsText = ""
                    addValidationError = nil
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.primary)
                        .padding(8)
                        .background(AppTheme.primary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(arr.addTorrent)
                .disabled(isRunningTorrentAction)

                Button {
                    Task {
                        guard !isRunningTorrentAction else { return }
                        isRunningTorrentAction = true
                        defer { isRunningTorrentAction = false }
                        do {
                            HapticManager.medium()
                            try await requireClient().toggleAlternativeSpeedLimits()
                            actionMessage = arr.altLimitsToggled
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                actionMessage = nil
                            }
                            await fetchData(silent: false, includeTorrents: true)
                        } catch {
                            state = .error(.custom(error.localizedDescription))
                            HapticManager.error()
                        }
                    }
                } label: {
                    Image(systemName: "speedometer")
                        .foregroundStyle(AppTheme.info)
                        .padding(8)
                        .background(AppTheme.info.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isRunningTorrentAction)

                Button {
                    Task {
                        guard !isRunningTorrentAction else { return }
                        isRunningTorrentAction = true
                        defer { isRunningTorrentAction = false }
                        HapticManager.medium()
                        do {
                            try await requireClient().resumeAll()
                            actionMessage = arr.allResumed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                actionMessage = nil
                            }
                            await fetchData(silent: false, includeTorrents: true)
                        } catch {
                            state = .error(.custom(error.localizedDescription))
                            HapticManager.error()
                        }
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .foregroundStyle(AppTheme.running)
                        .padding(8)
                        .background(AppTheme.running.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isRunningTorrentAction)
                .padding(.horizontal, 4)
                
                Button {
                    Task {
                        guard !isRunningTorrentAction else { return }
                        isRunningTorrentAction = true
                        defer { isRunningTorrentAction = false }
                        HapticManager.medium()
                        do {
                            try await requireClient().pauseAll()
                            actionMessage = arr.allPaused
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                actionMessage = nil
                            }
                            await fetchData(silent: false, includeTorrents: true)
                        } catch {
                            state = .error(.custom(error.localizedDescription))
                            HapticManager.error()
                        }
                    }
                } label: {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(AppTheme.warning)
                        .padding(8)
                        .background(AppTheme.warning.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isRunningTorrentAction)
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
            
            ForEach(displayedTorrents) { torrent in
                torrentRow(torrent)
            }
        }
        .padding(.top, 24)
    }
    
    private func torrentRow(_ torrent: QbittorrentTorrent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                if torrent.isDownloading {
                    Image(systemName: "arrow.down.app.fill")
                        .foregroundStyle(AppTheme.running)
                } else if torrent.isUploading {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(AppTheme.info)
                } else if torrent.isPaused {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(AppTheme.warning)
                } else if torrent.isChecking {
                    Image(systemName: "arrow.2.squarepath")
                        .foregroundStyle(AppTheme.primary)
                } else if torrent.isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.stopped)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.running)
                }
                
                Text(torrent.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Menu {
                    Button(torrent.isPaused ? localizer.t.actionResume : localizer.t.actionPause) {
                        Task {
                            await performTorrentAction(successMessage: torrent.isPaused ? arr.torrentResumed : arr.torrentPaused) {
                                if torrent.isPaused {
                                    try await requireClient().resumeTorrent(hash: torrent.hash)
                                } else {
                                    try await requireClient().pauseTorrent(hash: torrent.hash)
                                }
                            }
                        }
                    }

                    Button(arr.recheck) {
                        Task {
                            await performTorrentAction(successMessage: arr.recheckStarted) {
                                try await requireClient().recheckTorrent(hash: torrent.hash)
                            }
                        }
                    }

                    Button(arr.reannounce) {
                        Task {
                            await performTorrentAction(successMessage: arr.reannounceQueued) {
                                try await requireClient().reannounceTorrent(hash: torrent.hash)
                            }
                        }
                    }

                    Button(localizer.t.delete) {
                        Task {
                            await performTorrentAction(successMessage: arr.torrentDeleted) {
                                try await requireClient().deleteTorrent(hash: torrent.hash, deleteFiles: false)
                            }
                        }
                    }

                    Button(arr.deleteWithData, role: .destructive) {
                        pendingDeleteWithFilesHash = torrent.hash
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(4)
                }
                .disabled(isRunningTorrentAction)
            }
            
            ProgressView(value: min(max(torrent.progress, 0.0), 1.0))
                .tint(torrent.isError ? AppTheme.stopped : (torrent.isPaused ? AppTheme.textMuted : AppTheme.primary))
            
            HStack {
                Text("\(Formatters.formatBytes(Double(torrent.downloaded))) / \(Formatters.formatBytes(Double(torrent.size)))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Spacer()

                if let ratio = torrent.ratio {
                    Text("\(arr.ratioLabel): \(String(format: "%.2f", ratio))")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.info)
                        .padding(.trailing, 2)
                }
                
                if torrent.dlspeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                        Text("\(Formatters.formatBytes(Double(torrent.dlspeed)))/s")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.running)
                }
                if torrent.upspeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                        Text("\(Formatters.formatBytes(Double(torrent.upspeed)))/s")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.info)
                    .padding(.leading, 6)
                }
            }

            HStack {
                if torrent.eta > 0 {
                    Text("\(arr.etaLabel): \(formatETA(seconds: torrent.eta))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if let seeds = torrent.num_seeds, let leechs = torrent.num_leechs {
                    Text("\(arr.seedsLeechersLabel): \(seeds)/\(leechs)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            let category = torrent.category ?? ""
            let tags = torrent.tags ?? ""
            if !category.isEmpty || !tags.isEmpty {
                HStack(spacing: 6) {
                    if !category.isEmpty {
                        Text(category)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.12), in: Capsule())
                    }
                    if !tags.isEmpty {
                        Text(tags)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    @MainActor
    private func performTorrentAction(successMessage: String, _ action: () async throws -> Void) async {
        guard !isRunningTorrentAction else { return }
        isRunningTorrentAction = true
        defer { isRunningTorrentAction = false }

        do {
            HapticManager.light()
            try await action()
            actionMessage = successMessage
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                actionMessage = nil
            }
            await fetchData(silent: false, includeTorrents: true)
        } catch {
            state = .error(.custom(error.localizedDescription))
            HapticManager.error()
        }
    }

    @MainActor
    private func submitAddTorrents() async {
        let normalized = Self.normalizedTorrentURLs(from: addURLsText)
        guard !normalized.isEmpty else {
            addValidationError = arr.addTorrentInvalid
            HapticManager.error()
            return
        }
        addValidationError = nil
        await performTorrentAction(successMessage: arr.torrentAdded) {
            try await requireClient().addTorrents(urls: normalized.joined(separator: "\n"))
        }
        if case .loaded = state {
            showAddSheet = false
            addURLsText = ""
        }
    }

    /// Validates magnet / http(s) lines for add form.
    static func normalizedTorrentURLs(from raw: String) -> [String] {
        raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                let lower = line.lowercased()
                return lower.hasPrefix("magnet:")
                    || lower.hasPrefix("http://")
                    || lower.hasPrefix("https://")
            }
    }

    private func requireClient() throws -> QbittorrentAPIClient {
        guard let client else {
            throw APIError.notConfigured
        }
        return client
    }

    private func filterTitle(_ filter: QbittorrentFilter) -> String {
        switch filter {
        case .all: return arr.filterAll
        case .downloading: return arr.filterActive
        case .completed: return arr.filterDone
        case .paused: return arr.filterPaused
        }
    }

    private func formatETA(seconds: Int64) -> String {
        guard seconds > 0 else { return "--" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(minutes % 60)m" }
        let days = hours / 24
        return "\(days)d \(hours % 24)h"
    }
}

private enum QbittorrentFilter: CaseIterable {
    case all
    case downloading
    case completed
    case paused
}
