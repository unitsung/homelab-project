import SwiftUI
import UniformTypeIdentifiers

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
    @State private var isSelecting = false
    @State private var selectedHashes: Set<String> = []
    @State private var categoryFilter: String? = nil // nil = all
    @State private var showTorrentFileImporter = false
    @State private var detailTorrent: QbittorrentTorrent?
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

            if isSelecting {
                selectionBar
            }
            
            if !displayedTorrents.isEmpty {
                torrentsListSection
            } else if case .loaded = state {
                emptyTorrentsView
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
        .sheet(item: $detailTorrent) { torrent in
            QbittorrentTorrentDetailSheet(
                torrent: torrent,
                clientProvider: { try requireClient() }
            )
            .environment(localizer)
        }
        .fileImporter(
            isPresented: $showTorrentFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "torrent") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            Task { await importTorrentFiles(result) }
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
                Text(connectionLabel(transferInfo.connection_status))
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
        let isError = text.localizedCaseInsensitiveContains("fail")
            || text.localizedCaseInsensitiveContains("error")
            || text.contains("失败")
            || text.contains("错误")
        return HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? AppTheme.danger : AppTheme.running)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isError ? AppTheme.danger : AppTheme.running)
            Spacer()
        }
        .padding(12)
        .background(
            (isError ? AppTheme.danger : AppTheme.running).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private var filterSection: some View {
        VStack(spacing: 10) {
            Picker(arr.filterAll, selection: $selectedFilter) {
                ForEach(QbittorrentFilter.allCases, id: \.self) { filter in
                    Text(filterTitle(filter)).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if !categoryOptions.isEmpty {
                Picker(localizer.t.qbCategoryAll, selection: Binding(
                    get: {
                        if let categoryFilter {
                            return categoryFilter.isEmpty ? "__none__" : categoryFilter
                        }
                        return "__all__"
                    },
                    set: { value in
                        switch value {
                        case "__all__": categoryFilter = nil
                        case "__none__": categoryFilter = ""
                        default: categoryFilter = value
                        }
                    }
                )) {
                    Text(localizer.t.qbCategoryAll).tag("__all__")
                    if categoryOptions.contains("") {
                        Text(localizer.t.qbCategoryNone).tag("__none__")
                    }
                    ForEach(categoryOptions.filter { !$0.isEmpty }, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textMuted)
                TextField(arr.searchTorrents, text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    isSelecting.toggle()
                    if !isSelecting { selectedHashes.removeAll() }
                } label: {
                    Text(isSelecting ? localizer.t.done : localizer.t.qbSelect)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 8)
    }

    /// Distinct category values from current torrents ("" = uncategorized).
    private var categoryOptions: [String] {
        let cats = Set(torrents.map { ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines) })
        return cats.sorted { a, b in
            if a.isEmpty { return false }
            if b.isEmpty { return true }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text(String(format: localizer.t.qbSelectedCount, selectedHashes.count))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button(localizer.t.qbResumeSelected) {
                Task { await batchControl(resume: true) }
            }
            .disabled(selectedHashes.isEmpty || isRunningTorrentAction)
            Button(localizer.t.qbPauseSelected) {
                Task { await batchControl(resume: false) }
            }
            .disabled(selectedHashes.isEmpty || isRunningTorrentAction)
            Button(localizer.t.qbDeleteSelected, role: .destructive) {
                Task { await batchDelete(deleteFiles: false) }
            }
            .disabled(selectedHashes.isEmpty || isRunningTorrentAction)
        }
        .font(.caption.weight(.semibold))
        .padding(.vertical, 4)
    }

    private var emptyTorrentsView: some View {
        let hasAny = !torrents.isEmpty
        return VStack(spacing: 10) {
            Image(systemName: hasAny ? "line.3.horizontal.decrease.circle" : "arrow.down.circle")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.textMuted)
            Text(hasAny ? localizer.t.qbEmptyFilterNoMatch : localizer.t.qbEmptyNoTorrents)
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
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

            if let categoryFilter {
                let cat = (torrent.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard cat == categoryFilter else { return false }
            }

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
                Menu {
                    Button {
                        addURLsText = ""
                        addValidationError = nil
                        showAddSheet = true
                    } label: {
                        Label(arr.addTorrent, systemImage: "link")
                    }
                    Button {
                        showTorrentFileImporter = true
                    } label: {
                        Label(localizer.t.qbAddTorrentFile, systemImage: "doc.badge.plus")
                    }
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
                            showActionError(error)
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
                            showActionError(error)
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
                            showActionError(error)
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelecting {
                            toggleSelect(torrent.hash)
                        } else {
                            detailTorrent = torrent
                        }
                    }
            }
        }
        .padding(.top, 24)
    }
    
    private func torrentRow(_ torrent: QbittorrentTorrent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                if isSelecting {
                    Image(systemName: selectedHashes.contains(torrent.hash) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedHashes.contains(torrent.hash) ? AppTheme.primary : AppTheme.textMuted)
                        .font(.title3)
                        .padding(.trailing, 2)
                }
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
            
            HStack(spacing: 8) {
                ProgressView(value: min(max(torrent.progress, 0.0), 1.0))
                    .tint(torrent.isError ? AppTheme.stopped : (torrent.isPaused ? AppTheme.textMuted : AppTheme.primary))
                Text("\(Int((min(max(torrent.progress, 0), 1) * 100).rounded()))%")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            
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
            showActionBanner(successMessage, isError: false)
            await fetchData(silent: true, includeTorrents: true)
        } catch {
            showActionError(error)
        }
    }

    private func showActionError(_ error: Error) {
        let message = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        showActionBanner(message, isError: true)
        HapticManager.error()
    }

    private func showActionBanner(_ message: String, isError: Bool) {
        actionMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + (isError ? 3.5 : 2.0)) {
            if actionMessage == message { actionMessage = nil }
        }
    }

    private func connectionLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "connected": return localizer.t.qbConnectionConnected
        case "disconnected": return localizer.t.qbConnectionDisconnected
        case "firewalled": return localizer.t.qbConnectionFirewalled
        default: return raw.capitalized
        }
    }

    private func toggleSelect(_ hash: String) {
        if selectedHashes.contains(hash) {
            selectedHashes.remove(hash)
        } else {
            selectedHashes.insert(hash)
        }
    }

    @MainActor
    private func batchControl(resume: Bool) async {
        guard !selectedHashes.isEmpty, !isRunningTorrentAction else { return }
        isRunningTorrentAction = true
        defer { isRunningTorrentAction = false }
        let hashes = Array(selectedHashes)
        do {
            let client = try requireClient()
            // One multi-hash request (qB accepts pipe-separated hashes).
            if resume {
                try await client.resumeTorrents(hashes: hashes)
            } else {
                try await client.pauseTorrents(hashes: hashes)
            }
            showActionBanner(String(format: localizer.t.qbBatchResultFormat, hashes.count, 0), isError: false)
            HapticManager.success()
        } catch {
            showActionError(error)
            return
        }
        await fetchData(silent: true, includeTorrents: true)
    }

    @MainActor
    private func batchDelete(deleteFiles: Bool) async {
        guard !selectedHashes.isEmpty, !isRunningTorrentAction else { return }
        isRunningTorrentAction = true
        defer { isRunningTorrentAction = false }
        let hashes = Array(selectedHashes)
        do {
            let client = try requireClient()
            try await client.deleteTorrents(hashes: hashes, deleteFiles: deleteFiles)
            selectedHashes.removeAll()
            isSelecting = false
            showActionBanner(String(format: localizer.t.qbBatchResultFormat, hashes.count, 0), isError: false)
            HapticManager.success()
        } catch {
            showActionError(error)
            return
        }
        await fetchData(silent: true, includeTorrents: true)
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

    @MainActor
    private func importTorrentFiles(_ result: Result<[URL], Error>) async {
        switch result {
        case .failure(let error):
            showActionError(error)
        case .success(let urls):
            guard !urls.isEmpty else { return }
            var files: [(fileName: String, data: Data)] = []
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    files.append((url.lastPathComponent, data))
                } catch {
                    showActionError(error)
                    return
                }
            }
            await performTorrentAction(successMessage: arr.torrentAdded) {
                try await requireClient().addTorrentFiles(files)
            }
        }
    }
}

private enum QbittorrentFilter: CaseIterable {
    case all
    case downloading
    case completed
    case paused
}

// MARK: - Detail sheet

private struct QbittorrentTorrentDetailSheet: View {
    let torrent: QbittorrentTorrent
    let clientProvider: () throws -> QbittorrentAPIClient

    @Environment(Localizer.self) private var localizer
    @Environment(\.dismiss) private var dismiss
    @State private var files: [QbittorrentTorrentFile] = []
    @State private var trackers: [QbittorrentTracker] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var dlLimitKBps: String = ""
    @State private var upLimitKBps: String = ""
    @State private var limitsMessage: String?
    @State private var isSavingLimits = false

    private var arr: ArrStrings { localizer.arr }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(torrent.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("\(Int((min(max(torrent.progress, 0), 1) * 100).rounded()))%")
                            .font(.caption.monospacedDigit().weight(.semibold))
                        ProgressView(value: min(max(torrent.progress, 0), 1))
                    }
                    LabeledContent {
                        Text("\(Formatters.formatBytes(Double(torrent.downloaded))) / \(Formatters.formatBytes(Double(torrent.size)))")
                    } label: {
                        Text(arr.download)
                    }
                    if let ratio = torrent.ratio {
                        LabeledContent(arr.ratioLabel) {
                            Text(String(format: "%.2f", ratio))
                        }
                    }
                    if let cat = torrent.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.primary.opacity(0.12), in: Capsule())
                    }
                    if let tags = torrent.tags, !tags.isEmpty {
                        Text(tags)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField(localizer.t.qbDownloadLimit, text: $dlLimitKBps)
                        .keyboardType(.numberPad)
                    TextField(localizer.t.qbUploadLimit, text: $upLimitKBps)
                        .keyboardType(.numberPad)
                    Text(localizer.t.qbLimitUnlimited)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await applyLimits() }
                    } label: {
                        if isSavingLimits {
                            ProgressView()
                        } else {
                            Text(localizer.t.qbApplyLimits)
                        }
                    }
                    .disabled(isSavingLimits)
                    if let limitsMessage {
                        Text(limitsMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.running)
                    }
                } header: {
                    Text(arr.download)
                }

                Section(localizer.t.qbTrackers) {
                    if isLoading {
                        ProgressView()
                    } else if trackers.isEmpty {
                        Text(localizer.t.qbNoTrackers).foregroundStyle(.secondary)
                    } else {
                        ForEach(trackers) { tracker in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tracker.url)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(2)
                                HStack {
                                    Text(tracker.statusLabel)
                                    Spacer()
                                    if let seeds = tracker.num_seeds, let peers = tracker.num_peers {
                                        Text("S:\(seeds) P:\(peers)")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(localizer.t.qbFiles) {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text(localizer.t.loading)
                        }
                    } else if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    } else if files.isEmpty {
                        Text(localizer.t.qbNoFiles)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(files) { file in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                HStack {
                                    Text(Formatters.formatBytes(Double(file.size)))
                                    Spacer()
                                    Text("\(file.progressPercent)%")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                ProgressView(value: min(max(file.progress, 0), 1))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(localizer.t.qbTorrentDetail)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.close) { dismiss() }
                }
            }
            .task { await loadDetails() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func loadDetails() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try clientProvider()
            async let filesTask = client.getTorrentFiles(hash: torrent.hash)
            async let trackersTask = client.getTorrentTrackers(hash: torrent.hash)
            async let dlTask = client.getDownloadLimit(hash: torrent.hash)
            async let upTask = client.getUploadLimit(hash: torrent.hash)
            files = try await filesTask
            trackers = (try? await trackersTask) ?? []
            let dl = (try? await dlTask) ?? -1
            let up = (try? await upTask) ?? -1
            dlLimitKBps = dl < 0 ? "" : "\(max(0, dl / 1024))"
            upLimitKBps = up < 0 ? "" : "\(max(0, up / 1024))"
            errorText = nil
        } catch {
            errorText = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            files = []
        }
    }

    @MainActor
    private func applyLimits() async {
        isSavingLimits = true
        defer { isSavingLimits = false }
        do {
            let client = try clientProvider()
            let dl: Int64 = {
                let t = dlLimitKBps.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let kb = Int64(t), kb > 0 else { return -1 }
                return kb * 1024
            }()
            let up: Int64 = {
                let t = upLimitKBps.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let kb = Int64(t), kb > 0 else { return -1 }
                return kb * 1024
            }()
            try await client.setDownloadLimit(hash: torrent.hash, limit: dl)
            try await client.setUploadLimit(hash: torrent.hash, limit: up)
            limitsMessage = localizer.t.qbLimitsSaved
            HapticManager.success()
        } catch {
            limitsMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            HapticManager.error()
        }
    }
}
