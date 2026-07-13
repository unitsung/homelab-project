import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Native file browser modeled after OpenList web UX:
/// folder → enter · file → built-in preview (player / image / text / md / html / pdf)
/// + open external player / copy link / delete (same operation model as OpenList web).
struct OpenListFileBrowserView: View {
    let instanceId: UUID

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer

    @State private var client: OpenListAPIClient?
    @State private var path: String = "/"
    @State private var items: [FileItem] = []
    @State private var canWrite = false
    @State private var state: LoadableState<Void> = .idle

    @State private var searchText = ""
    @State private var searchResults: [FileItem] = []
    @State private var isSearching = false

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []

    @State private var actionMessage: String?
    @State private var toastTask: Task<Void, Never>?

    /// File opened in the bottom sheet (details + play)
    @State private var activeItem: FileItem?
    @State private var activeDetail: FileDetail?
    @State private var activeError: String?
    @State private var activeLoading = false

    /// Player picker shown after tapping 播放
    @State private var showPlayerPicker = false
    @State private var playerPickerItem: FileItem?

    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showFileImporter = false

    @State private var pendingDelete: [FileItem] = []
    @State private var showDeleteConfirm = false

    @State private var renameItem: FileItem?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    enum PathPickMode: Identifiable {
        case move([FileItem])
        case copy([FileItem])
        case extract(FileItem)
        var id: String {
            switch self {
            case .move: return "move"
            case .copy: return "copy"
            case .extract: return "extract"
            }
        }
    }
    @State private var pathPickMode: PathPickMode?
    @State private var shareURL: URL?
    @State private var showShare = false

    /// Full-screen built-in player session (item-based so cover is never blank).
    private struct BuiltInPlaySession: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
        let isAudio: Bool
        var externalSubtitleURL: URL? = nil
    }
    @State private var builtInPlay: BuiltInPlaySession?

    private var breadcrumbs: [FileBreadcrumb] { OpenListPath.breadcrumbs(for: path) }
    private var displayedItems: [FileItem] { isSearching ? searchResults : items }
    private var selectedItems: [FileItem] { displayedItems.filter { selectedIDs.contains($0.id) } }
    private var serviceColor: Color { ServiceType.openlist.colors.primary }

    /// Edge-swipe walks folder hierarchy; the nav bar back button always leaves OpenList → Home.
    private var shouldCaptureEdgeSwipeForFolderUp: Bool {
        isSearching || path != "/"
    }

    var body: some View {
        ServiceDashboardLayout(
            serviceType: .openlist,
            instanceId: instanceId,
            state: state,
            onRefresh: { await reload(silent: false) }
        ) {
            if let actionMessage {
                toastBanner(actionMessage)
            }

            breadcrumbBar

            // Only mount when needed — empty ScrollView used to add/remove height between folders.
            if canWrite && !isSelecting {
                actionToolbar
            }

            if isSelecting {
                selectionBar
            }

            if displayedItems.isEmpty, case .loaded = state {
                emptyState
            } else {
                // Stable list identity — avoid remount/transition thrash when path changes.
                LazyVStack(spacing: 8) {
                    ForEach(displayedItems) { item in
                        fileRow(item)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: localizer.t.filesSearchPlaceholder)
        .onSubmit(of: .search) { Task { await runSearch() } }
        .onChange(of: searchText) { _, v in
            if v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isSearching = false
                searchResults = []
            }
        }
        .navigationTitle(titleForPath)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    OpenListTasksView(instanceId: instanceId)
                } label: {
                    Image(systemName: "list.bullet.rectangle.portrait")
                }
                .accessibilityLabel(localizer.t.filesTasks)

                Button(isSelecting ? localizer.t.done : localizer.t.filesSelect) {
                    if isSelecting {
                        isSelecting = false
                        selectedIDs.removeAll()
                    } else {
                        isSelecting = true
                    }
                }
            }
        }
        .background {
            // Only edge-swipe is hierarchical; system back button stays “pop to Home”.
            OpenListHierarchicalBackChrome(
                interceptsSystemPop: shouldCaptureEdgeSwipeForFolderUp,
                onBack: { Task { await handleEdgeSwipeBack() } }
            )
        }
        .task {
            client = await servicesStore.openlistClient(instanceId: instanceId)
            await reload(silent: false)
        }
        .sheet(item: $activeItem) { item in
            OpenListFilePreviewView(
                item: item,
                detail: activeDetail,
                isLoading: activeLoading,
                errorMessage: activeError,
                client: client,
                loadTextContent: {
                    guard let client else { throw APIError.notConfigured }
                    let cached = activeDetail?.item.path == item.path ? activeDetail : nil
                    return try await client.fetchTextContent(path: item.path, using: cached)
                },
                onPlayBuiltIn: {
                    Task { await openBuiltInPlayer(item) }
                },
                onOpenExternalPlayer: { player in
                    Task { await play(item: item, player: player) }
                },
                onDownload: {
                    Task { await downloadItems([item]) }
                },
                onCopyLink: { Task { await copyLink(for: item) } },
                onDelete: {
                    activeItem = nil
                    pendingDelete = [item]
                    showDeleteConfirm = true
                },
                onClose: { activeItem = nil },
                onSaved: {
                    Task { await reload(silent: true) }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $pathPickMode) { mode in
            if let client {
                OpenListFolderPickerView(
                    client: client,
                    title: {
                        switch mode {
                        case .move: return localizer.t.filesMoveTo
                        case .copy: return localizer.t.filesCopyTo
                        case .extract: return localizer.t.filesExtractTo
                        }
                    }(),
                    confirmTitle: localizer.t.confirm,
                    onPick: { dest in
                        Task { await handlePathPick(mode, destination: dest) }
                    }
                )
            }
        }
        .fullScreenCover(item: $builtInPlay) { session in
            OpenListMediaPlayerView(
                url: session.url,
                title: session.title,
                isAudio: session.isAudio,
                externalSubtitleURL: session.externalSubtitleURL
            )
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                OpenListShareSheet(items: [shareURL])
            }
        }
        .sheet(isPresented: $showPlayerPicker, onDismiss: {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !showPlayerPicker { playerPickerItem = nil }
            }
        }) {
            OpenListPlayerPickerView(
                fileName: playerPickerItem?.name ?? "",
                onExternal: { player in
                    guard let item = playerPickerItem else { return }
                    Task { await play(item: item, player: player) }
                },
                onCopyLink: {
                    guard let item = playerPickerItem else { return }
                    Task { await copyLink(for: item) }
                }
            )
        }
        .alert(localizer.t.filesNewFolder, isPresented: $showNewFolderAlert) {
            TextField(localizer.t.filesFolderName, text: $newFolderName)
            Button(localizer.t.cancel, role: .cancel) { newFolderName = "" }
            Button(localizer.t.confirm) {
                Task { await createFolder() }
            }
        }
        .sheet(isPresented: $showRenameAlert, onDismiss: {
            // Keep text until sheet fully closes; clear after.
            if !showRenameAlert {
                renameItem = nil
            }
        }) {
            NavigationStack {
                Form {
                    Section {
                        TextField(localizer.t.filesFileName, text: $renameText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        if let renameItem {
                            Text(renameItem.path)
                                .font(.caption2)
                        }
                    }
                }
                .navigationTitle(localizer.t.filesRename)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizer.t.cancel) {
                            showRenameAlert = false
                            renameItem = nil
                            renameText = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localizer.t.confirm) {
                            Task { await performRename() }
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.height(220), .medium])
            .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleImport(result) }
        }
        .confirmationDialog(
            localizer.t.filesDeleteConfirm,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(localizer.t.delete, role: .destructive) {
                Task { await performDelete(pendingDelete) }
            }
            Button(localizer.t.cancel, role: .cancel) { pendingDelete = [] }
        } message: {
            Text(pendingDelete.map(\.name).joined(separator: ", "))
        }
    }

    // MARK: - Chrome

    private var titleForPath: String {
        path == "/" ? localizer.t.filesRootTitle : (path.split(separator: "/").last.map(String.init) ?? localizer.t.filesRootTitle)
    }

    private func toastBanner(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(serviceColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Button {
                        Task { await navigate(to: crumb.path) }
                    } label: {
                        Text(index == 0 ? localizer.t.filesRootTitle : crumb.title)
                            .font(.subheadline.weight(index == breadcrumbs.count - 1 ? .semibold : .regular))
                            .foregroundStyle(index == breadcrumbs.count - 1 ? Color.primary : serviceColor)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(index == breadcrumbs.count - 1)
                }
            }
        }
    }

    /// OpenList-web style action strip: new folder / upload when writable
    private var actionToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Label(localizer.t.filesNewFolder, systemImage: "folder.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(serviceColor)

                Button {
                    showFileImporter = true
                } label: {
                    Label(localizer.t.filesUpload, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(serviceColor)
            }
        }
    }

    private var selectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Text(String(format: localizer.t.filesSelectedCount, selectedIDs.count))
                    .font(.subheadline.weight(.semibold))
                Button(localizer.t.filesDownload) {
                    Task { await downloadItems(selectedItems) }
                }
                .disabled(selectedItems.filter { !$0.isDirectory }.isEmpty)
                Button(localizer.t.filesCopy) {
                    pathPickMode = .copy(selectedItems)
                }
                .disabled(selectedIDs.isEmpty || !canWrite)
                Button(localizer.t.filesMove) {
                    pathPickMode = .move(selectedItems)
                }
                .disabled(selectedIDs.isEmpty || !canWrite)
                Button(localizer.t.filesCopyLink) {
                    Task { await copyLinks(for: selectedItems) }
                }
                .disabled(selectedItems.filter { !$0.isDirectory }.isEmpty)
                Button(role: .destructive) {
                    pendingDelete = selectedItems
                    showDeleteConfirm = true
                } label: {
                    Text(localizer.t.delete)
                }
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textSecondary)
            Text(isSearching ? localizer.t.noData : localizer.t.filesEmptyFolder)
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            if canWrite && !isSearching {
                Button {
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Text(localizer.t.filesNewFolder)
                }
                .buttonStyle(.borderedProminent)
                .tint(serviceColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Rows

    @ViewBuilder
    private func fileRow(_ item: FileItem) -> some View {
        let selected = selectedIDs.contains(item.id)
        Button {
            Task { await handleTap(item) }
        } label: {
            FileRowView(item: item, isSelecting: isSelecting, isSelected: selected)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if item.isDirectory {
                Button { Task { await navigate(to: item.path) } } label: {
                    Label(localizer.t.filesOpen, systemImage: "folder")
                }
            } else {
                Button { Task { await openFileSheet(item) } } label: {
                    Label(localizer.t.filesPreview, systemImage: "eye")
                }
                if item.isVideoOrAudio {
                    Button {
                        Task { await openBuiltInPlayer(item) }
                    } label: {
                        Label(localizer.t.filesPlay, systemImage: "play.fill")
                    }
                    Button {
                        playerPickerItem = item
                        showPlayerPicker = true
                    } label: {
                        Label(localizer.t.filesOpenExternal, systemImage: "arrow.up.forward.app")
                    }
                }
                Button { Task { await downloadItems([item]) } } label: {
                    Label(localizer.t.filesDownload, systemImage: "arrow.down.circle")
                }
                Button { Task { await copyLink(for: item) } } label: {
                    Label(localizer.t.filesCopyLink, systemImage: "link")
                }
                if item.isArchive, canWrite {
                    Button {
                        pathPickMode = .extract(item)
                    } label: {
                        Label(localizer.t.filesExtract, systemImage: "doc.zipper")
                    }
                }
            }
            // Rename always offered; server enforces write permission.
            Button {
                renameItem = item
                renameText = item.name
                showRenameAlert = true
            } label: {
                Label(localizer.t.filesRename, systemImage: "pencil")
            }
            if canWrite {
                Button { pathPickMode = .copy([item]) } label: {
                    Label(localizer.t.filesCopy, systemImage: "doc.on.doc")
                }
                Button { pathPickMode = .move([item]) } label: {
                    Label(localizer.t.filesMove, systemImage: "folder")
                }
            }
            Button { toggleSelect(item) } label: {
                Label(
                    selected ? localizer.t.filesDeselect : localizer.t.filesSelect,
                    systemImage: selected ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            Divider()
            Button(role: .destructive) {
                pendingDelete = [item]
                showDeleteConfirm = true
            } label: {
                Label(localizer.t.delete, systemImage: "trash")
            }
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            HapticManager.medium()
            if !isSelecting { isSelecting = true }
            toggleSelect(item)
        }
    }

    // MARK: - Navigation / load

    /// Left-edge swipe: cancel search, or go up one folder. Does not leave OpenList.
    @MainActor
    private func handleEdgeSwipeBack() async {
        if isSearching {
            isSearching = false
            searchText = ""
            searchResults = []
            return
        }
        guard path != "/" else { return }
        await navigate(to: OpenListPath.parent(of: path))
    }

    @MainActor
    private func handleTap(_ item: FileItem) async {
        if isSelecting {
            toggleSelect(item)
            return
        }
        if item.isDirectory {
            await navigate(to: item.path)
            return
        }
        // File → OpenList-style built-in preview (player / image / text / …)
        await openFileSheet(item)
    }

    private func toggleSelect(_ item: FileItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        if !isSelecting { isSelecting = true }
    }

    @MainActor
    private func openFileSheet(_ item: FileItem) async {
        activeItem = item
        activeDetail = nil
        activeError = nil
        activeLoading = true
        defer { activeLoading = false }
        guard let client else {
            activeError = APIError.notConfigured.localizedDescription
            return
        }
        do {
            activeDetail = try await client.detail(path: item.path)
        } catch {
            activeError = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func play(item: FileItem, player: ExternalPlayerOption) async {
        do {
            let detail = try await ensureDetail(for: item)
            // OpenList-hosted /d link + sign — never use raw_url/CDN.
            guard let url = detail.playURL else {
                showToast(localizer.t.filesNoPlayableURL)
                return
            }
            let ok = await ExternalPlayerRouter.open(player: player, streamURL: url)
            if !ok {
                ExternalPlayerRouter.copyToPasteboard(url.absoluteString)
                showToast(localizer.t.filesPlayerOpenFailed)
            } else {
                showToast(String(format: localizer.t.filesOpenedInPlayer, player.displayName))
            }
            activeItem = nil
            playerPickerItem = nil
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func copyLink(for item: FileItem) async {
        do {
            let detail = try await ensureDetail(for: item)
            guard let url = detail.playURL else {
                showToast(localizer.t.filesNoPlayableURL)
                return
            }
            ExternalPlayerRouter.copyToPasteboard(url.absoluteString)
            showToast(localizer.t.filesLinkCopied)
            activeItem = nil
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func copyLinks(for items: [FileItem]) async {
        var links: [String] = []
        for item in items where !item.isDirectory {
            if let d = try? await ensureDetail(for: item), let url = d.playURL {
                links.append(url.absoluteString)
            }
        }
        guard !links.isEmpty else {
            showToast(localizer.t.filesNoPlayableURL)
            return
        }
        ExternalPlayerRouter.copyToPasteboard(links.joined(separator: "\n"))
        showToast(localizer.t.filesLinkCopied)
    }

    @MainActor
    private func createFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/"), let client else { return }
        let full = OpenListPath.join(parent: path, name: name)
        do {
            try await client.mkdir(path: full)
            showToast(localizer.t.filesFolderCreated)
            await reload(silent: true)
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
        newFolderName = ""
    }

    @MainActor
    private func handleImport(_ result: Result<[URL], Error>) async {
        guard let client else { return }
        switch result {
        case .failure(let error):
            showToast(error.localizedDescription)
        case .success(let urls):
            var okCount = 0
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    let name = url.lastPathComponent
                    try await client.upload(fileName: name, data: data, toDirectory: path)
                    okCount += 1
                } catch {
                    showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
                }
            }
            if okCount > 0 {
                showToast(String(format: localizer.t.filesUploadedCount, okCount))
                await reload(silent: true)
            }
        }
    }

    @MainActor
    private func performDelete(_ targets: [FileItem]) async {
        guard let client, !targets.isEmpty else { return }
        let grouped = Dictionary(grouping: targets) { $0.parentDirectory }
        do {
            for (dir, files) in grouped {
                try await client.remove(names: files.map(\.name), in: dir)
            }
            selectedIDs.subtract(targets.map(\.id))
            showToast(localizer.t.filesDeleted)
            await reload(silent: true)
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
        pendingDelete = []
    }

    private func ensureDetail(for item: FileItem) async throws -> FileDetail {
        if let activeDetail, activeItem?.id == item.id { return activeDetail }
        guard let client else { throw APIError.notConfigured }
        return try await client.detail(path: item.path)
    }

    @MainActor
    private func reload(silent: Bool) async {
        guard let client else {
            if !silent { state = .error(.notConfigured) }
            return
        }
        // Keep chrome + previous list when already loaded (no skeleton flash on refresh).
        if !silent, case .loaded = state {
            // soft refresh
        } else if !silent {
            state = .loading
        }
        do {
            let result = try await client.list(path: path)
            items = result.items
            canWrite = result.writable
            state = .loaded(())
        } catch let error as APIError {
            if !silent { state = .error(error) }
        } catch {
            if !silent { state = .error(.networkError(error)) }
        }
    }

    /// Folder change without skeleton flash or list remount animations.
    @MainActor
    private func navigate(to newPath: String) async {
        let normalized = OpenListPath.normalize(newPath)
        let from = path
        if normalized == from, !isSearching { return }

        isSearching = false
        searchText = ""
        searchResults = []
        isSelecting = false
        selectedIDs.removeAll()
        // Update path immediately so title/breadcrumb stay in sync; keep previous rows until fetch returns.
        path = normalized

        guard let client else {
            state = .error(.notConfigured)
            return
        }
        do {
            let result = try await client.list(path: normalized)
            // Direct assignment (no withAnimation / id remount) — avoids layout flicker.
            items = result.items
            canWrite = result.writable
            state = .loaded(())
        } catch let error as APIError {
            path = from
            state = .error(error)
        } catch {
            path = from
            state = .error(.networkError(error))
        }
    }

    @MainActor
    private func runSearch() async {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let client else { return }
        isSearching = true
        do {
            searchResults = try await client.search(keyword: q, path: path)
            state = .loaded(())
        } catch let error as APIError {
            state = .error(error)
        } catch {
            state = .error(.networkError(error))
        }
    }

    private func showToast(_ message: String) {
        actionMessage = message
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if !Task.isCancelled { actionMessage = nil }
        }
    }

    @MainActor
    private func performRename() async {
        // Capture before dismissing sheet so binding is not cleared mid-call.
        let item = renameItem
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item, let client, !name.isEmpty else { return }
        guard name != item.name else {
            showRenameAlert = false
            renameItem = nil
            return
        }
        do {
            try await client.rename(path: item.path, name: name)
            showRenameAlert = false
            renameItem = nil
            renameText = ""
            showToast(localizer.t.filesRenamed)
            await reload(silent: true)
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func handlePathPick(_ mode: PathPickMode, destination: String) async {
        guard let client else { return }
        do {
            switch mode {
            case .move(let items):
                let grouped = Dictionary(grouping: items) { $0.parentDirectory }
                for (dir, files) in grouped {
                    try await client.move(names: files.map(\.name), from: dir, to: destination)
                }
                showToast(localizer.t.filesMoved)
                selectedIDs.removeAll()
                isSelecting = false
            case .copy(let items):
                let grouped = Dictionary(grouping: items) { $0.parentDirectory }
                for (dir, files) in grouped {
                    try await client.copy(names: files.map(\.name), from: dir, to: destination)
                }
                showToast(localizer.t.filesCopied)
            case .extract(let item):
                try await client.decompress(
                    name: item.name,
                    from: item.parentDirectory,
                    to: destination
                )
                showToast(localizer.t.filesExtractStarted)
            }
            await reload(silent: true)
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
        pathPickMode = nil
    }

    @MainActor
    private func downloadItems(_ items: [FileItem]) async {
        guard let client else { return }
        var lastURL: URL?
        var count = 0
        for item in items where !item.isDirectory {
            do {
                lastURL = try await client.downloadToLocalFile(path: item.path, preferredName: item.name)
                count += 1
            } catch {
                showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
            }
        }
        if count > 0 {
            showToast(String(format: localizer.t.filesDownloadedCount, count))
            if let lastURL {
                shareURL = lastURL
                showShare = true
            }
        }
    }

    @MainActor
    private func openBuiltInPlayer(_ item: FileItem) async {
        do {
            let detail = try await ensureDetail(for: item)
            // Prefer OpenList /d stream for media (sign-auth). contentURL (/p) as fallback.
            guard let url = detail.playURL ?? detail.contentURL else {
                showToast(localizer.t.filesNoPlayableURL)
                return
            }
            var subtitleURL: URL?
            if item.previewKind == .video {
                subtitleURL = await findSiblingSubtitleURL(for: item)
            }
            AppLogger.shared.info(
                "openBuiltIn path=\(item.path) url=\(url.absoluteString) sub=\(subtitleURL?.lastPathComponent ?? "none")",
                source: "OpenList"
            )
            let session = BuiltInPlaySession(
                url: url,
                title: item.name,
                isAudio: item.previewKind == .audio,
                externalSubtitleURL: subtitleURL
            )
            // Dismiss preview sheet first — fullScreenCover over sheet often blanks / fails.
            activeItem = nil
            try? await Task.sleep(nanoseconds: 350_000_000)
            builtInPlay = session
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
    }

    /// Look for same-basename .srt / .vtt next to the video (OpenList-style companion files).
    @MainActor
    private func findSiblingSubtitleURL(for item: FileItem) async -> URL? {
        guard let client else { return nil }
        let stem = (item.name as NSString).deletingPathExtension
        let parent = item.parentDirectory
        guard let listing = try? await client.list(path: parent) else { return nil }
        let candidates = listing.items.filter { sub in
            guard !sub.isDirectory else { return false }
            let ext = sub.fileExtension
            guard ext == "srt" || ext == "vtt" else { return false }
            let subStem = (sub.name as NSString).deletingPathExtension
            return subStem == stem || sub.name.hasPrefix(stem)
        }
        // Prefer exact stem match, then any prefix match; srt before vtt
        let sorted = candidates.sorted { a, b in
            let aExact = (a.name as NSString).deletingPathExtension == stem
            let bExact = (b.name as NSString).deletingPathExtension == stem
            if aExact != bExact { return aExact && !bExact }
            if a.fileExtension != b.fileExtension { return a.fileExtension == "srt" }
            return a.name < b.name
        }
        guard let best = sorted.first else { return nil }
        guard let d = try? await client.detail(path: best.path) else { return nil }
        return d.contentURL ?? d.playURL
    }
}

// MARK: - Hierarchical back (swipe / system pop)

/// When browsing a subfolder, disable the nav-stack interactive pop and install a
/// left-edge swipe that walks up one folder level (same as the custom back button).
private struct OpenListHierarchicalBackChrome: UIViewControllerRepresentable {
    var interceptsSystemPop: Bool
    var onBack: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBack: onBack)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onBack = onBack
        context.coordinator.interceptsSystemPop = interceptsSystemPop
        DispatchQueue.main.async {
            context.coordinator.sync(host: uiViewController)
        }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onBack: () -> Void
        var interceptsSystemPop = false

        private weak var navigationController: UINavigationController?
        private var edgeGesture: UIScreenEdgePanGestureRecognizer?
        private var restoredInteractivePop: Bool?

        init(onBack: @escaping () -> Void) {
            self.onBack = onBack
        }

        func sync(host: UIViewController) {
            guard let nav = resolveNavigationController(from: host) else { return }
            navigationController = nav

            if interceptsSystemPop {
                if restoredInteractivePop == nil {
                    restoredInteractivePop = nav.interactivePopGestureRecognizer?.isEnabled ?? true
                }
                nav.interactivePopGestureRecognizer?.isEnabled = false
                installEdgeGesture(on: nav)
                edgeGesture?.isEnabled = true
            } else {
                edgeGesture?.isEnabled = false
                if let restored = restoredInteractivePop {
                    nav.interactivePopGestureRecognizer?.isEnabled = restored
                } else {
                    nav.interactivePopGestureRecognizer?.isEnabled = true
                }
            }
        }

        func teardown() {
            if let edgeGesture {
                edgeGesture.view?.removeGestureRecognizer(edgeGesture)
            }
            edgeGesture = nil
            if let nav = navigationController {
                nav.interactivePopGestureRecognizer?.isEnabled = restoredInteractivePop ?? true
            }
            navigationController = nil
        }

        private func installEdgeGesture(on nav: UINavigationController) {
            if edgeGesture != nil { return }
            let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
            gesture.edges = .left
            gesture.delegate = self
            nav.view.addGestureRecognizer(gesture)
            edgeGesture = gesture
        }

        @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard interceptsSystemPop else { return }
            guard gesture.state == .ended || gesture.state == .cancelled else { return }
            let translation = gesture.translation(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)
            // Mimic system pop threshold.
            if translation.x > 56 || velocity.x > 450 {
                onBack()
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Prefer edge-back over competing horizontal pans when intercepting.
            interceptsSystemPop && gestureRecognizer === edgeGesture
        }

        private func resolveNavigationController(from host: UIViewController) -> UINavigationController? {
            if let nav = host.navigationController { return nav }
            var parent = host.parent
            while let current = parent {
                if let nav = current as? UINavigationController { return nav }
                if let nav = current.navigationController { return nav }
                parent = current.parent
            }
            // SwiftUI hosting often needs a responder walk from the view.
            var responder: UIResponder? = host.view
            while let current = responder {
                if let nav = current as? UINavigationController { return nav }
                if let vc = current as? UIViewController, let nav = vc.navigationController { return nav }
                responder = current.next
            }
            return nil
        }
    }
}

// MARK: - Share sheet

private struct OpenListShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Row

struct FileRowView: View {
    let item: FileItem
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? ServiceType.openlist.colors.primary : AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ServiceType.openlist.colors.bg)
                    .frame(width: 52, height: 52)
                if let thumb = item.thumbnailURL {
                    AsyncImage(url: thumb) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: item.systemImageName)
                                .font(.title3)
                                .foregroundStyle(ServiceType.openlist.colors.primary)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Image(systemName: item.systemImageName)
                        .font(.title3)
                        .foregroundStyle(ServiceType.openlist.colors.primary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    if item.isDirectory {
                        Text("Folder")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(item.previewKind.shortLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ServiceType.openlist.colors.primary.opacity(0.85))
                    }
                    if let modified = item.modifiedAt {
                        Text(modified, style: .relative)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            if !isSelecting {
                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(minWidth: 28, minHeight: 44)
                } else {
                    Image(systemName: trailingGlyph(for: item))
                        .font(.title3)
                        .foregroundStyle(ServiceType.openlist.colors.primary.opacity(0.9))
                        .frame(minWidth: 36, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 72)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? ServiceType.openlist.colors.bg : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? ServiceType.openlist.colors.primary.opacity(0.35) : .clear, lineWidth: 1.5)
        )
    }

    private func trailingGlyph(for item: FileItem) -> String {
        switch item.previewKind {
        case .video, .audio: return "play.circle.fill"
        case .image: return "photo.circle"
        case .markdown, .text, .html: return "eye.circle"
        case .pdf: return "doc.circle"
        case .download, .none: return "ellipsis.circle"
        }
    }
}

private extension FilePreviewKind {
    var shortLabel: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Audio"
        case .image: return "Image"
        case .markdown: return "Markdown"
        case .html: return "HTML"
        case .text: return "Text"
        case .pdf: return "PDF"
        case .download: return "File"
        case .none: return ""
        }
    }
}
