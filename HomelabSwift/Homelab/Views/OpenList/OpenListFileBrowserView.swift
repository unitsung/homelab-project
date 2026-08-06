import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Direction of folder hierarchy change — drives slide-in/out transitions.
enum OpenListFolderNavDirection {
    case forward
    case backward
    case none

    var reversed: OpenListFolderNavDirection {
        switch self {
        case .forward: return .backward
        case .backward: return .forward
        case .none: return .none
        }
    }
}

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
    /// In-flight folder change (enter / up / breadcrumb). Distinct from full-screen `.loading`.
    @State private var isNavigating = false
    @State private var folderNavDirection: OpenListFolderNavDirection = .none
    /// Bumps on each navigate call so stale responses are ignored.
    @State private var navigateGeneration = 0

    @State private var searchText = ""
    @State private var searchResults: [FileItem] = []
    @State private var isSearching = false
    /// True while a search request is in flight (distinct from “showing search results”).
    @State private var isSearchLoading = false
    /// Bumps on each search so stale responses cannot overwrite newer results.
    @State private var searchGeneration = 0

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var sortMode: OpenListSortMode = .nameAsc
    @State private var viewMode: OpenListViewMode = .list

    @State private var actionMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var uploadProgress: (current: Int, total: Int)?

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
    @State private var showOfflineDownload = false
    @State private var offlineURLsText = ""

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
        var openlistDirectoryPath: String? = nil
    }
    @State private var builtInPlay: BuiltInPlaySession?

    private var breadcrumbs: [FileBreadcrumb] { OpenListPath.breadcrumbs(for: path) }
    private var displayedItems: [FileItem] {
        sortMode.sorted(isSearching ? searchResults : items)
    }
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

            if let uploadProgress {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(format: localizer.t.filesUploadingProgress, uploadProgress.current, uploadProgress.total))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            sortBar

            if isSelecting {
                selectionBar
            }

            folderListBody
                .animation(.easeInOut(duration: 0.28), value: isNavigating)
                .animation(.easeInOut(duration: 0.28), value: path)
                .animation(.easeInOut(duration: 0.22), value: isSearching)
                .animation(.easeInOut(duration: 0.22), value: isSearchLoading)
        }
        .searchable(text: $searchText, prompt: localizer.t.filesSearchPlaceholder)
        .onSubmit(of: .search) { Task { await runSearch() } }
        .onChange(of: searchText) { _, v in
            if v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchGeneration += 1
                isSearching = false
                isSearchLoading = false
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
                externalSubtitleURL: session.externalSubtitleURL,
                openlistInstanceId: instanceId,
                openlistDirectoryPath: session.openlistDirectoryPath
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
        .sheet(isPresented: $showOfflineDownload) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localizer.t.filesOfflineDownloadHint)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                    TextEditor(text: $offlineURLsText)
                        .font(.body.monospaced())
                        .frame(minHeight: 160)
                        .padding(8)
                        .glassCard(cornerRadius: 12, tint: serviceColor.opacity(0.08))
                    Spacer(minLength: 0)
                }
                .padding(16)
                .navigationTitle(localizer.t.filesOfflineDownload)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizer.t.cancel) { showOfflineDownload = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localizer.t.filesOfflineDownloadSubmit) {
                            Task { await submitOfflineDownload() }
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        // Centered alert (not bottom action sheet) — clearer on notched iPhones.
        .alert(
            localizer.t.filesDeleteConfirm,
            isPresented: $showDeleteConfirm
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
            .glassCard(cornerRadius: 12, tint: serviceColor.opacity(0.18))
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
                }
                .buttonStyle(.glass)
                .tint(serviceColor)
                .disabled(uploadProgress != nil)

                Button {
                    showFileImporter = true
                } label: {
                    Label(localizer.t.filesUpload, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(serviceColor)
                .disabled(uploadProgress != nil)

                Button {
                    offlineURLsText = ""
                    showOfflineDownload = true
                } label: {
                    Label(localizer.t.filesOfflineDownload, systemImage: "arrow.down.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
                .tint(serviceColor)
            }
        }
    }

    private var sortBar: some View {
        HStack {
            Text(localizer.t.filesSortBy)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Picker(localizer.t.filesSortBy, selection: $sortMode) {
                Text(localizer.t.filesSortName).tag(OpenListSortMode.nameAsc)
                Text(localizer.t.filesSortDate).tag(OpenListSortMode.dateDesc)
                Text(localizer.t.filesSortSize).tag(OpenListSortMode.sizeDesc)
                Text(localizer.t.filesSortType).tag(OpenListSortMode.type)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(serviceColor)
            .foregroundStyle(serviceColor)
            Spacer()
            Picker(localizer.t.filesViewList, selection: $viewMode) {
                Image(systemName: "list.bullet").tag(OpenListViewMode.list)
                Image(systemName: "square.grid.2x2").tag(OpenListViewMode.grid)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 120)
            .tint(serviceColor)
            .accessibilityLabel(viewMode == .list ? localizer.t.filesViewList : localizer.t.filesViewGrid)
        }
        .tint(serviceColor)
        .padding(.vertical, 2)
    }

    private var selectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Text(String(format: localizer.t.filesSelectedCount, selectedIDs.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Button(localizer.t.filesDownload) {
                    Task { await downloadItems(selectedItems) }
                }
                .buttonStyle(.glassProminent)
                .tint(serviceColor)
                .disabled(selectedItems.filter { !$0.isDirectory }.isEmpty)
                Button(localizer.t.filesCopy) {
                    pathPickMode = .copy(selectedItems)
                }
                .buttonStyle(.glass)
                .tint(serviceColor)
                .disabled(selectedIDs.isEmpty || !canWrite)
                Button(localizer.t.filesMove) {
                    pathPickMode = .move(selectedItems)
                }
                .buttonStyle(.glass)
                .tint(serviceColor)
                .disabled(selectedIDs.isEmpty || !canWrite)
                Button(localizer.t.filesCopyLink) {
                    Task { await copyLinks(for: selectedItems) }
                }
                .buttonStyle(.glass)
                .tint(serviceColor)
                .disabled(selectedItems.filter { !$0.isDirectory }.isEmpty)
                Button(role: .destructive) {
                    pendingDelete = selectedItems
                    showDeleteConfirm = true
                } label: {
                    Text(localizer.t.delete)
                }
                .buttonStyle(.glass)
                .tint(AppTheme.danger)
                .disabled(selectedIDs.isEmpty)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(serviceColor)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var folderListBody: some View {
        ZStack {
            if isNavigating || isSearchLoading {
                folderLoadingPlaceholder
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if displayedItems.isEmpty, case .loaded = state {
                emptyState
                    .id("empty-\(path)-\(isSearching)")
                    .transition(folderContentTransition)
            } else if !displayedItems.isEmpty {
                Group {
                    if viewMode == .grid {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(displayedItems) { item in
                                fileGridCell(item)
                            }
                        }
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(displayedItems) { item in
                                fileRow(item)
                            }
                        }
                    }
                }
                .id("list-\(path)-\(isSearching)-\(viewMode.rawValue)")
                .transition(folderContentTransition)
            }
        }
        // Reserve space so the layout does not jump when swapping placeholder ↔ list.
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .top)
    }

    private var folderContentTransition: AnyTransition {
        switch folderNavDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .none:
            return .opacity
        }
    }

    private var folderLoadingPlaceholder: some View {
        let label = isSearchLoading ? localizer.t.filesSearching : localizer.t.loading
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            ForEach(0..<6, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
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
                    Label(localizer.t.filesNewFolder, systemImage: "folder.badge.plus")
                }
                .buttonStyle(.glassProminent)
                .tint(serviceColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Rows

    @ViewBuilder
    private func fileGridCell(_ item: FileItem) -> some View {
        let selected = selectedIDs.contains(item.id)
        Button {
            Task { await handleTap(item) }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.isDirectory ? serviceColor.opacity(0.14) : ServiceType.openlist.colors.bg)
                        .frame(height: 88)
                    if let thumb = item.thumbnailURL, !item.isDirectory {
                        OpenListCachedThumbnail(url: thumb, systemImageName: item.systemImageName)
                            .frame(height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: item.isDirectory ? "folder.fill" : item.systemImageName)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(serviceColor)
                    }
                    if isSelecting {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(selected ? serviceColor : .white.opacity(0.9))
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .top)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .glassCard(cornerRadius: 12, tint: selected ? serviceColor.opacity(0.16) : nil)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(serviceColor.opacity(0.45), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu { fileContextMenu(item) }
    }

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
        .contextMenu { fileContextMenu(item) }
        .onLongPressGesture(minimumDuration: 0.45) {
            if !isSelecting { isSelecting = true }
            toggleSelect(item)
        }
    }

    @ViewBuilder
    private func fileContextMenu(_ item: FileItem) -> some View {
        let selected = selectedIDs.contains(item.id)
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

    // MARK: - Navigation / load

    /// Left-edge swipe: cancel search, or go up one folder. Does not leave OpenList.
    @MainActor
    private func handleEdgeSwipeBack() async {
        if isSearching {
            isSearching = false
            isSearchLoading = false
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
    private func submitOfflineDownload() async {
        let lines = offlineURLsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                let l = line.lowercased()
                return l.hasPrefix("http://") || l.hasPrefix("https://") || l.hasPrefix("magnet:")
            }
        guard !lines.isEmpty else {
            showToast(localizer.t.filesOfflineDownloadInvalid)
            return
        }
        guard let client else {
            showToast(APIError.notConfigured.localizedDescription)
            return
        }
        do {
            try await client.addOfflineDownload(urls: lines, toDirectory: path)
            showOfflineDownload = false
            offlineURLsText = ""
            showToast(localizer.t.filesOfflineDownloadStarted)
        } catch {
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func handleImport(_ result: Result<[URL], Error>) async {
        guard let client else { return }
        switch result {
        case .failure(let error):
            showToast(error.localizedDescription)
        case .success(let urls):
            guard !urls.isEmpty else { return }
            var okCount = 0
            var failCount = 0
            uploadProgress = (0, urls.count)
            defer { uploadProgress = nil }
            for (index, url) in urls.enumerated() {
                uploadProgress = (index + 1, urls.count)
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    let name = url.lastPathComponent
                    try await client.upload(fileName: name, data: data, toDirectory: path)
                    okCount += 1
                } catch {
                    failCount += 1
                    if urls.count == 1 {
                        showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
                    }
                }
            }
            if okCount > 0 {
                var msg = String(format: localizer.t.filesUploadedCount, okCount)
                if failCount > 0 {
                    msg += " · " + String(format: localizer.t.filesUploadFailedCount, failCount)
                }
                showToast(msg)
                await reload(silent: true)
            } else if failCount > 0, urls.count > 1 {
                showToast(String(format: localizer.t.filesUploadFailedCount, failCount))
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
        // Avoid clobbering an in-flight folder change with a stale list response.
        if isNavigating { return }

        let pathAtStart = path
        let hadContent: Bool = {
            if case .loaded = state { return true }
            return !items.isEmpty
        }()

        // Keep chrome + previous list when already loaded (no skeleton flash on refresh).
        if !silent, case .loaded = state {
            // soft refresh
        } else if !silent {
            state = .loading
        }
        do {
            let result = try await client.list(path: pathAtStart)
            guard pathAtStart == path, !isNavigating else { return }
            items = result.items
            canWrite = result.writable
            state = .loaded(())
        } catch let error as APIError {
            guard pathAtStart == path, !isNavigating else { return }
            // Prefer toast over full-page error so an already-browsable tree stays usable.
            if hadContent {
                if !silent {
                    showToast(error.localizedDescription)
                    state = .loaded(())
                }
            } else if !silent {
                state = .error(error)
            }
        } catch {
            guard pathAtStart == path, !isNavigating else { return }
            if hadContent {
                if !silent {
                    showToast(error.localizedDescription)
                    state = .loaded(())
                }
            } else if !silent {
                state = .error(.networkError(error))
            }
        }
    }

    /// Enter / leave a folder with loading placeholder + directional slide transition.
    @MainActor
    private func navigate(to newPath: String) async {
        let normalized = OpenListPath.normalize(newPath)
        let from = path
        let previousItems = items
        let previousWritable = canWrite
        if normalized == from, !isSearching, !isNavigating { return }

        let fromDepth = Self.pathDepth(from)
        let toDepth = Self.pathDepth(normalized)
        if toDepth > fromDepth {
            folderNavDirection = .forward
        } else if toDepth < fromDepth {
            folderNavDirection = .backward
        } else {
            folderNavDirection = .none
        }

        navigateGeneration += 1
        let generation = navigateGeneration

        searchGeneration += 1
        isSearching = false
        isSearchLoading = false
        searchText = ""
        searchResults = []
        isSelecting = false
        selectedIDs.removeAll()

        // Path + title update immediately; clear stale rows and show loading animation.
        withAnimation(.easeInOut(duration: 0.22)) {
            path = normalized
            items = []
            isNavigating = true
        }

        guard let client else {
            isNavigating = false
            state = .error(.notConfigured)
            return
        }
        do {
            let result = try await client.list(path: normalized)
            guard generation == navigateGeneration else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                items = result.items
                canWrite = result.writable
                isNavigating = false
            }
            state = .loaded(())
        } catch let error as APIError {
            guard generation == navigateGeneration else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                path = from
                items = previousItems
                canWrite = previousWritable
                isNavigating = false
                folderNavDirection = folderNavDirection.reversed
            }
            // Toast only — never flip ServiceDashboardLayout to full-page error mid-browse.
            state = .loaded(())
            showToast(error.localizedDescription)
        } catch {
            guard generation == navigateGeneration else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                path = from
                items = previousItems
                canWrite = previousWritable
                isNavigating = false
                folderNavDirection = folderNavDirection.reversed
            }
            state = .loaded(())
            showToast(error.localizedDescription)
        }
    }

    private static func pathDepth(_ path: String) -> Int {
        let n = OpenListPath.normalize(path)
        if n == "/" { return 0 }
        return n.split(separator: "/").filter { !$0.isEmpty }.count
    }

    @MainActor
    private func runSearch() async {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let client else { return }
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true
        isSearchLoading = true
        searchResults = []
        defer {
            if generation == searchGeneration {
                isSearchLoading = false
            }
        }
        do {
            let found = try await client.search(keyword: q, path: path)
            guard generation == searchGeneration else { return }
            searchResults = found
            if case .error = state { state = .loaded(()) }
        } catch {
            guard generation == searchGeneration else { return }
            // Keep the browser on screen; surface the failure as a toast.
            if case .error = state { state = .loaded(()) }
            showToast((error as? APIError)?.localizedDescription ?? error.localizedDescription)
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
        // VLCKit handles MKV/AVI/etc. — no longer bounce users to external apps for those.
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
                externalSubtitleURL: subtitleURL,
                openlistDirectoryPath: item.parentDirectory
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
        let subtitleExts: Set<String> = ["srt", "vtt", "ass", "ssa", "sub"]
        let candidates = listing.items.filter { sub in
            guard !sub.isDirectory else { return false }
            let ext = sub.fileExtension
            guard subtitleExts.contains(ext) else { return false }
            let subStem = (sub.name as NSString).deletingPathExtension
            return subStem == stem || sub.name.hasPrefix(stem)
        }
        // Prefer exact stem match, then any prefix match; srt/ass before vtt
        let preferredOrder = ["srt", "ass", "ssa", "vtt", "sub"]
        let sorted = candidates.sorted { a, b in
            let aExact = (a.name as NSString).deletingPathExtension == stem
            let bExact = (b.name as NSString).deletingPathExtension == stem
            if aExact != bExact { return aExact && !bExact }
            let aRank = preferredOrder.firstIndex(of: a.fileExtension) ?? 99
            let bRank = preferredOrder.firstIndex(of: b.fileExtension) ?? 99
            if aRank != bRank { return aRank < bRank }
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

// MARK: - Sort

enum OpenListViewMode: String, CaseIterable, Identifiable {
    case list
    case grid
    var id: String { rawValue }
}

enum OpenListSortMode: String, CaseIterable, Identifiable {
    case nameAsc
    case dateDesc
    case sizeDesc
    case type

    var id: String { rawValue }

    func sorted(_ items: [FileItem]) -> [FileItem] {
        // Folders first for name/type; date/size keep natural mix but folders still lead for type.
        switch self {
        case .nameAsc:
            return items.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .dateDesc:
            return items.sorted { a, b in
                let ad = a.modifiedAt ?? .distantPast
                let bd = b.modifiedAt ?? .distantPast
                if ad != bd { return ad > bd }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .sizeDesc:
            return items.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                if a.size != b.size { return a.size > b.size }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .type:
            return items.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                let ae = a.fileExtension
                let be = b.fileExtension
                if ae != be { return ae.localizedCaseInsensitiveCompare(be) == .orderedAscending }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }
}

// MARK: - Thumbnail cache

enum OpenListThumbnailCache {
    // NSCache is thread-safe; mark unsafe for Swift 6 static isolation.
    nonisolated(unsafe) private static let cache = NSCache<NSURL, UIImage>()

    static func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    static func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

// MARK: - Cached thumbnail

private struct OpenListCachedThumbnail: View {
    let url: URL
    let systemImageName: String

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Image(systemName: systemImageName)
                    .font(.title3)
                    .foregroundStyle(ServiceType.openlist.colors.primary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            if let cached = OpenListThumbnailCache.image(for: url) {
                image = cached
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let ui = UIImage(data: data) {
                    OpenListThumbnailCache.store(ui, for: url)
                    image = ui
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
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

    @Environment(Localizer.self) private var localizer
    private var accent: Color { ServiceType.openlist.colors.primary }

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? accent : AppTheme.textSecondary)
                    .frame(width: 22, height: 22)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.isDirectory ? accent.opacity(0.14) : ServiceType.openlist.colors.bg)
                    .frame(width: 40, height: 40)
                if let thumb = item.thumbnailURL, !item.isDirectory {
                    OpenListCachedThumbnail(url: thumb, systemImageName: item.systemImageName)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: item.isDirectory ? "folder.fill" : item.systemImageName)
                        .font(.body.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(accent)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitleLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)

            if !isSelecting {
                Image(systemName: item.isDirectory ? "chevron.right" : trailingGlyph(for: item))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.isDirectory ? AppTheme.textMuted : accent.opacity(0.85))
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .glassCard(
            cornerRadius: 12,
            tint: isSelected ? accent.opacity(0.16) : nil
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? accent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    private var subtitleLine: String {
        var parts: [String] = []
        if item.isDirectory {
            parts.append(localizer.t.filesFolderKind)
        } else {
            parts.append(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
            let kind = item.previewKind.shortLabel
            if kind != "File" { parts.append(kind) }
        }
        if let modified = item.modifiedAt {
            parts.append(modified.formatted(.relative(presentation: .named)))
        }
        return parts.joined(separator: " · ")
    }

    private func trailingGlyph(for item: FileItem) -> String {
        switch item.previewKind {
        case .video, .audio: return "play.fill"
        case .image: return "photo"
        case .markdown, .text, .html: return "doc.text"
        case .pdf: return "doc.richtext"
        case .download, .none: return "ellipsis"
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
