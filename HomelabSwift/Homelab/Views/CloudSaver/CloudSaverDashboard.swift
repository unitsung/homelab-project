import SwiftUI

struct CloudSaverDashboard: View {
    let instanceId: UUID

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(\.openURL) private var openURL

    @State private var client: CloudSaverAPIClient?
    @State private var tab: CloudSaverMainTab = .douban
    @State private var selectedChip: CloudSaverDoubanChip = .default
    @State private var doubanItems: [CloudSaverDoubanItem] = []
    @State private var isLoadingDouban = false

    @State private var keyword = ""
    @State private var results: [CloudSaverSearchResult] = []
    @State private var hasMore = false
    @State private var lastMessageId = ""
    @State private var isSearching = false
    @State private var isLoadingMore = false

    @State private var errorMessage: String?
    @State private var transferMessage: String?
    @State private var transferState: CloudSaverTransferState?
    @State private var transferringIds: Set<String> = []
    @State private var transferredIds: Set<String> = []
    @State private var settings: CloudSaverSettings = .empty
    @State private var showSettings = false
    @State private var selectedSearch: CloudSaverSearchResult?
    @State private var imageBaseURL: String = ""
    @State private var imageToken: String = ""
    @State private var imageAllowSelfSigned = true
    @State private var linkHealthById: [String: CloudSaverLinkHealth] = [:]
    @State private var sourceFilter: CloudSaverSourceFilter = .all
    @State private var resultSort: CloudSaverResultSort = .defaultOrder
    @State private var doubanSort: CloudSaverResultSort = .defaultOrder
    @State private var toastMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var accent: Color { ServiceType.cloudsaver.colors.primary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $tab) {
                    ForEach(CloudSaverMainTab.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                if tab == .douban {
                    doubanSection
                } else {
                    searchSection
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let transferMessage {
                    Text(transferMessage)
                        .font(.footnote)
                        .foregroundStyle(transferState == .failed ? .red : AppTheme.textSecondary)
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(ServiceType.cloudsaver.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !settings.libraryOpenURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        openLibrary()
                    } label: {
                        Image(systemName: "play.rectangle.fill")
                    }
                    .accessibilityLabel("打开媒体库")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                CloudSaverSettingsView(settings: $settings, instanceId: instanceId) {
                    CloudSaverSettingsStore.save(settings, instanceId: instanceId)
                    showSettings = false
                }
            }
        }
        .navigationDestination(item: $selectedSearch) { item in
            CloudSaverDetailView(instanceId: instanceId, item: item)
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }
        }
        .animation(.spring(duration: 0.3), value: toastMessage)
        .task {
            settings = CloudSaverSettingsStore.load(instanceId: instanceId)
            refreshImageContext()
            client = await servicesStore.cloudsaverClient(instanceId: instanceId)
            // Token may be refreshed after configure; re-read for image proxy auth
            refreshImageContext()
            await loadDouban()
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .douban, doubanItems.isEmpty {
                Task { await loadDouban() }
            }
        }
    }

    // MARK: - Douban

    private var doubanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLOUDSAVER · 豆瓣榜单")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)

            Text(selectedChip.title)
                .font(.title3.weight(.bold))

            Text("点击海报搜索资源。115 可「想看」到默认目录；其它网盘进详情选目录保存。")
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CloudSaverDoubanChip.all) { chip in
                        chipButton(chip)
                    }
                }
            }

            Picker("排序", selection: $doubanSort) {
                ForEach(CloudSaverResultSort.allCases) { s in
                    Text(s.title).tag(s)
                }
            }
            .pickerStyle(.segmented)

            if isLoadingDouban && doubanItems.isEmpty {
                ProgressView("加载榜单…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if doubanItems.isEmpty {
                ContentUnavailableView(
                    "暂无榜单",
                    systemImage: "rectangle.grid.2x2",
                    description: Text("下拉重试或检查 CloudSaver 服务")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(displayedDoubanItems) { item in
                        Button {
                            Task { await openDoubanItem(item) }
                        } label: {
                            CloudSaverPosterCell(
                                title: item.title,
                                imageURL: item.cover,
                                badge: item.rate.isEmpty ? nil : item.rate,
                                badgeColor: CloudSaverRateColor.color(for: item.rate),
                                subtitle: doubanSubtitle(item),
                                showTransferred: false,
                                serviceBaseURL: imageBaseURL,
                                bearerToken: imageToken,
                                allowSelfSigned: imageAllowSelfSigned,
                                footerHint: item.reputation.isEmpty ? nil : item.reputation,
                                topTrailingTag: item.honorTag.isEmpty ? nil : item.honorTag
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func chipButton(_ chip: CloudSaverDoubanChip) -> some View {
        let selected = chip.id == selectedChip.id
        return Button {
            selectedChip = chip
            Task { await loadDouban() }
        } label: {
            Text(chip.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? accent : AppTheme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("请输入搜索关键词", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit { Task { await search(reset: true) } }

                Button {
                    Task { await search(reset: true) }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .opacity(isSearching ? 0.6 : 1)
                }
                .disabled(isSearching || keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("来源", selection: $sourceFilter) {
                        ForEach(CloudSaverSourceFilter.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("排序", selection: $resultSort) {
                        ForEach(CloudSaverResultSort.allCases) { s in
                            Text(s.title).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Single loading indicator for search (avoid button + status + empty-state all spinning)
            if isSearching, results.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("正在搜索…")
                        .font(.subheadline.weight(.medium))
                    Text("正在搜索多个资源频道，通常需要数秒")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else if results.isEmpty, !isSearching {
                ContentUnavailableView(
                    "搜索资源",
                    systemImage: "magnifyingglass",
                    description: Text("输入片名，或从豆瓣榜单点海报跳转搜索")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(displayedSearchResults) { item in
                        VStack(spacing: 8) {
                            Button {
                                selectedSearch = item
                            } label: {
                                CloudSaverPosterCell(
                                    title: item.title,
                                    imageURL: item.imageURL,
                                    badge: searchBadge(for: item),
                                    badgeColor: searchBadgeColor(for: item),
                                    subtitle: searchSubtitle(for: item),
                                    showTransferred: transferredIds.contains(item.id),
                                    serviceBaseURL: imageBaseURL,
                                    bearerToken: imageToken,
                                    allowSelfSigned: imageAllowSelfSigned,
                                    footerHint: "详情"
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())

                            if item.cloudType == .cloud115 {
                                Button {
                                    Task { await wantToWatch(item) }
                                } label: {
                                    HStack(spacing: 6) {
                                        if transferringIds.contains(item.id) {
                                            ProgressView().controlSize(.small)
                                        }
                                        Text(transferredIds.contains(item.id) ? "已想看" : "想看")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(accent)
                                .disabled(
                                    transferringIds.contains(item.id)
                                        || transferredIds.contains(item.id)
                                        || linkHealthById[item.id]?.isInvalid == true
                                )
                            }
                        }
                    }
                }

                if hasMore {
                    Button {
                        Task { await search(reset: false) }
                    } label: {
                        if isLoadingMore {
                            ProgressView()
                        } else {
                            Text("加载更多")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadDouban() async {
        guard let client else {
            errorMessage = "服务未就绪"
            return
        }
        isLoadingDouban = true
        errorMessage = nil
        defer { isLoadingDouban = false }
        do {
            doubanItems = try await client.fetchDoubanHot(
                type: selectedChip.type,
                category: selectedChip.category,
                api: selectedChip.api,
                limit: 50
            )
            if doubanItems.isEmpty {
                errorMessage = "榜单为空，请换分类或稍后重试"
            }
        } catch {
            errorMessage = CloudSaverUserFacingError.message(from: error)
            doubanItems = []
        }
    }

    private func openDoubanItem(_ item: CloudSaverDoubanItem) async {
        keyword = item.title
        tab = .search
        await search(reset: true)
    }

    private func search(reset: Bool) async {
        let q = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard let client else {
            errorMessage = "服务未就绪"
            return
        }

        if reset {
            isSearching = true
            errorMessage = nil
            transferMessage = nil
            lastMessageId = ""
            // Clear previous results so user only sees loading, not stale hits
            results = []
            hasMore = false
            linkHealthById = [:]
            transferredIds = []
        } else {
            isLoadingMore = true
        }
        defer {
            isSearching = false
            isLoadingMore = false
        }

        do {
            let page = try await client.search(
                keyword: q,
                lastMessageId: reset ? nil : (lastMessageId.isEmpty ? nil : lastMessageId)
            )
            if reset {
                results = page.results
            } else {
                let existing = Set(results.map(\.id))
                results.append(contentsOf: page.results.filter { !existing.contains($0.id) })
            }
            hasMore = page.hasMore
            lastMessageId = page.lastMessageId
            if results.isEmpty {
                errorMessage = "未找到相关资源"
            } else if reset {
                Task { await probeLinkHealth(for: page.results) }
            }
        } catch {
            errorMessage = CloudSaverUserFacingError.message(from: error)
        }
    }

    /// 「想看」仅 115 → 默认目录（接口选中的 CID）。夸克等不展示。
    /// 后续可接 STRM / 刷新媒体库；当前成功语义为 transferred。
    private var displayedDoubanItems: [CloudSaverDoubanItem] {
        var items = doubanItems
        switch doubanSort {
        case .defaultOrder: break
        case .rating:
            items.sort { (Double($0.rate) ?? 0) > (Double($1.rate) ?? 0) }
        case .year:
            items.sort { ($0.year ?? 0) > ($1.year ?? 0) }
        }
        return items
    }

    private var displayedSearchResults: [CloudSaverSearchResult] {
        var items = results.filter { sourceFilter.matches($0.cloudType) }
        switch resultSort {
        case .defaultOrder:
            break
        case .rating:
            items.sort { lhs, rhs in
                let lr = ratingProxy(lhs)
                let rr = ratingProxy(rhs)
                if lr != rr { return lr > rr }
                return lhs.count > rhs.count
            }
        case .year:
            items.sort { yearProxy($0) > yearProxy($1) }
        }
        return items
    }

    private func doubanSubtitle(_ item: CloudSaverDoubanItem) -> String? {
        var parts: [String] = []
        if !item.subtitle.isEmpty { parts.append(item.subtitle) }
        if item.ratingCount > 0 {
            parts.append("\(item.ratingCount) 人评分")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func ratingProxy(_ item: CloudSaverSearchResult) -> Double {
        let text = item.title + " " + item.description
        if let r = try? NSRegularExpression(pattern: #"(?<![0-9])([0-9]\.[0-9])(?![0-9])"#),
           let m = r.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(m.range(at: 1), in: text) {
            return Double(text[range]) ?? 0
        }
        if case .valid(let n) = linkHealthById[item.id] { return Double(n) }
        return Double(item.count)
    }

    private func yearProxy(_ item: CloudSaverSearchResult) -> Int {
        let text = item.title + " " + item.description + " " + item.pubDate
        if let r = try? NSRegularExpression(pattern: #"(19|20)\d{2}"#),
           let m = r.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(m.range, in: text) {
            return Int(text[range]) ?? 0
        }
        return 0
    }

    private func wantToWatch(_ item: CloudSaverSearchResult) async {
        guard item.cloudType == .cloud115 else {
            transferMessage = "「想看」仅支持 115，其它网盘请打开详情选择目录保存"
            transferState = .failed
            return
        }
        guard let client else {
            transferMessage = "服务未就绪"
            transferState = .failed
            return
        }
        guard let dest = settings.defaultFolder(for: .cloud115) else {
            transferMessage = "请先在设置中选择 115 默认保存目录（从网盘列表点选，无需手填）"
            transferState = .failed
            showSettings = true
            return
        }

        transferringIds.insert(item.id)
        transferState = .transferring
        transferMessage = "正在转存到 \(dest.name)…"
        defer { transferringIds.remove(item.id) }

        do {
            let followUp = try await client.wantToWatch(
                result: item,
                folderId: dest.cid,
                folderName: dest.name,
                postSavePluginId: settings.resolvedPostSavePluginId
            )
            transferredIds.insert(item.id)
            transferState = .transferred
            var parts: [String] = ["已转存到「\(dest.name)」"]
            if let suffix = followUp.userSuffix {
                parts.append(suffix)
            }
            let hint = settings.ingestHint.trimmingCharacters(in: .whitespacesAndNewlines)
            if !hint.isEmpty {
                parts.append(hint)
            }
            let msg = parts.joined(separator: "。")
            transferMessage = msg
            showToast(msg)
        } catch {
            transferState = .failed
            transferMessage = CloudSaverUserFacingError.message(from: error)
        }
    }


    private func searchBadge(for item: CloudSaverSearchResult) -> String? {
        if case .invalid = linkHealthById[item.id] {
            return "失效"
        }
        if case .valid = linkHealthById[item.id] {
            return item.cloudType == .unknown ? "有效" : item.cloudType.displayName
        }
        return item.cloudType == .unknown ? nil : item.cloudType.displayName
    }

    private func searchBadgeColor(for item: CloudSaverSearchResult) -> Color {
        if case .invalid = linkHealthById[item.id] { return .red }
        if case .valid = linkHealthById[item.id] { return .green }
        return accent
    }

    private func searchSubtitle(for item: CloudSaverSearchResult) -> String? {
        var parts: [String] = []
        if !item.fileSize.isEmpty { parts.append(item.fileSize) }
        if case .checking = linkHealthById[item.id] {
            parts.append("检测中…")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Probe first N search results for dead shares (share-info empty/error).
    private func probeLinkHealth(for items: [CloudSaverSearchResult], limit: Int = 12) async {
        guard let client else { return }
        for item in items.prefix(limit) {
            if linkHealthById[item.id] != nil { continue }
            if item.shareCode.isEmpty {
                linkHealthById[item.id] = .invalid("无分享码")
                continue
            }
            if item.cloudType == .unknown {
                linkHealthById[item.id] = .unknown
                continue
            }
            linkHealthById[item.id] = .checking
            do {
                let info = try await client.shareInfo(
                    shareCode: item.shareCode,
                    receiveCode: item.receiveCode,
                    cloud: item.cloudType
                )
                linkHealthById[item.id] = info.files.isEmpty
                    ? .invalid("无文件")
                    : .valid(fileCount: info.files.count)
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? error.localizedDescription
                linkHealthById[item.id] = .invalid(msg)
            }
        }
    }

    private func refreshImageContext() {
        guard let instance = servicesStore.instance(id: instanceId) else { return }
        imageBaseURL = instance.url
        // Prefer non-empty token; password login stores JWT in token
        imageToken = instance.token.isEmpty ? (instance.apiKey ?? "") : instance.token
        imageAllowSelfSigned = instance.allowSelfSigned
    }

    private func openLibrary() {
        let raw = settings.libraryOpenURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), !raw.isEmpty else { return }
        openURL(url)
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

// MARK: - Poster cell (2-column card, 2:3 poster)

struct CloudSaverPosterCell: View {
    let title: String
    let imageURL: String
    let badge: String?
    let badgeColor: Color
    let subtitle: String?
    let showTransferred: Bool
    var serviceBaseURL: String = ""
    var bearerToken: String = ""
    var allowSelfSigned: Bool = true
    var footerHint: String? = nil
    /// Top-leading tag e.g. 推荐 / 一般
    var topTrailingTag: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fixed 2:3 poster box — image fills *inside* the box and cannot expand the card.
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    ZStack(alignment: .topTrailing) {
                        CloudSaverRemoteImage(
                            urlString: imageURL,
                            serviceBaseURL: serviceBaseURL,
                            bearerToken: bearerToken,
                            allowSelfSigned: allowSelfSigned
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                        if let topTrailingTag, !topTrailingTag.isEmpty {
                            Text(topTrailingTag)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }

                        if let badge, !badge.isEmpty {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(badgeColor.opacity(0.92))
                                .clipShape(Capsule())
                                .padding(8)
                        }

                        if showTransferred {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .green)
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            if let footerHint, !footerHint.isEmpty {
                Text(footerHint)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ServiceType.cloudsaver.colors.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Search filter / sort

enum CloudSaverSourceFilter: String, CaseIterable, Identifiable {
    case all, cloud115, quark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "全部来源"
        case .cloud115: return "115"
        case .quark: return "夸克"
        }
    }
    func matches(_ t: CloudSaverCloudType) -> Bool {
        switch self {
        case .all: return true
        case .cloud115: return t == .cloud115
        case .quark: return t == .quark
        }
    }
}

enum CloudSaverResultSort: String, CaseIterable, Identifiable {
    case defaultOrder, rating, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .defaultOrder: return "默认排序"
        case .rating: return "评分排序"
        case .year: return "年份排序"
        }
    }
}

// MARK: - Link health

enum CloudSaverLinkHealth: Equatable, Sendable {
    case unknown
    case checking
    case valid(fileCount: Int)
    case invalid(String)

    var label: String {
        switch self {
        case .unknown: return "未检测"
        case .checking: return "检测中…"
        case .valid(let n): return "有效（\(n) 个文件）"
        case .invalid(let m): return "失效：\(m)"
        }
    }

    var isInvalid: Bool {
        if case .invalid = self { return true }
        return false
    }
}

// MARK: - Settings

struct CloudSaverSettingsView: View {
    @Binding var settings: CloudSaverSettings
    var instanceId: UUID
    var onSave: () -> Void

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(\.dismiss) private var dismiss

    @State private var client: CloudSaverAPIClient?
    @State private var pickCloud: CloudSaverCloudType?

    var body: some View {
        Form {
            Section {
                defaultFolderRow(
                    title: "115 默认保存目录",
                    name: settings.defaultFolder115Name,
                    cid: settings.defaultFolder115Cid,
                    cloud: .cloud115
                )
                defaultFolderRow(
                    title: "夸克 默认保存目录",
                    name: settings.defaultFolderQuarkName,
                    cid: settings.defaultFolderQuarkCid,
                    cloud: .quark
                )
            } header: {
                Text("默认保存目录")
            } footer: {
                Text("目录从接口实时拉取，不写死 CID。点选即可设为默认。Cookie/登录过期时请到 CloudSaver 网页刷新网盘 Cookie。")
            }

            Section("播放 / 入库") {
                TextField("媒体库 URL（Emby/Jellyfin）", text: $settings.libraryOpenURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("转存成功提示（可选）", text: $settings.ingestHint)
            }

            Section {
                TextField("插件 ID（如 4）", text: $settings.postSavePluginId)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("想看后续（LitePan）")
            } footer: {
                Text("转存成功后调用 POST /api/plugins/run，触发 LitePan hooks（STRM / NFO / 刷 Emby 等）。留空则不调用；插件失败不影响已转存。")
            }

            Section {
                Text("「想看」仅 115，保存到上方默认目录。其它网盘请在详情浏览后保存。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("CloudSaver 设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { onSave() }
            }
        }
        .task {
            client = await servicesStore.cloudsaverClient(instanceId: instanceId)
        }
        .sheet(item: $pickCloud) { cloud in
            NavigationStack {
                CloudSaverFolderPickerSheet(
                    instanceId: instanceId,
                    cloud: cloud
                ) { cid, name in
                    settings.setDefaultFolder(cloud: cloud, cid: cid, name: name)
                    pickCloud = nil
                }
            }
        }
    }

    private func defaultFolderRow(title: String, name: String, cid: String, cloud: CloudSaverCloudType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if cid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("未设置 — 从网盘目录选择")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(name.isEmpty ? cid : name)
                Text("CID：\(cid)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Button {
                pickCloud = cloud
            } label: {
                Label("从网盘目录选择", systemImage: "folder.badge.plus")
            }
        }
        .padding(.vertical, 4)
    }
}

extension CloudSaverCloudType: Identifiable {
    public var id: String { rawValue }
}

/// Pick folder via GET /api/{cloud}/folders — never hardcode CIDs.
struct CloudSaverFolderPickerSheet: View {
    let instanceId: UUID
    let cloud: CloudSaverCloudType
    var onPick: (String, String) -> Void

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(\.dismiss) private var dismiss

    @State private var client: CloudSaverAPIClient?
    @State private var folders: [CloudSaverRemoteFolder] = []
    @State private var stack: [CloudSaverRemoteFolder] = []
    @State private var selectedCid = ""
    @State private var selectedName = ""
    @State private var isLoading = false
    @State private var error: String?

    private var accent: Color { ServiceType.cloudsaver.colors.primary }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        Button("根目录") {
                            stack = []
                            if cloud == .cloud115 {
                                selectedCid = "0"
                                selectedName = "根目录"
                            } else {
                                selectedCid = ""
                                selectedName = ""
                            }
                            Task { await load("0") }
                        }
                        ForEach(Array(stack.enumerated()), id: \.element.cid) { index, folder in
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Button(folder.name) {
                                stack = Array(stack.prefix(index + 1))
                                selectedCid = folder.cid
                                selectedName = stack.map(\.name).joined(separator: " / ")
                                Task { await load(folder.cid) }
                            }
                        }
                    }
                }
            } header: {
                Text("浏览 \(cloud.displayName) 目录")
            }

            if client == nil && isLoading {
                HStack { ProgressView(); Text("连接服务…") }
            } else if isLoading {
                HStack { ProgressView(); Text("加载目录…") }
            } else if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
                Button("重试") { Task { await load(stack.last?.cid ?? "0") } }
            } else if folders.isEmpty {
                Text("此目录下没有子文件夹（可仍将当前路径设为默认）")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(folders) { folder in
                    HStack {
                        Button {
                            selectedCid = folder.cid
                            selectedName = (stack.map(\.name) + [folder.name]).joined(separator: " / ")
                        } label: {
                            HStack {
                                Image(systemName: selectedCid == folder.cid ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCid == folder.cid ? accent : .secondary)
                                Image(systemName: "folder.fill").foregroundStyle(.orange)
                                Text(folder.name)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            stack.append(folder)
                            selectedCid = folder.cid
                            selectedName = stack.map(\.name).joined(separator: " / ")
                            Task { await load(folder.cid) }
                        } label: {
                            Image(systemName: "chevron.right.circle").foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !selectedCid.isEmpty {
                Section {
                    Text("已选：\(selectedName.isEmpty ? selectedCid : selectedName)")
                    Text(selectedCid)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("选择默认目录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("设为默认") {
                    let cid = selectedCid.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cid.isEmpty else { return }
                    if cloud == .quark, cid == "0" { return }
                    onPick(cid, selectedName.isEmpty ? cid : selectedName)
                }
                .disabled(selectedCid.isEmpty || (cloud == .quark && selectedCid == "0"))
            }
        }
        .task {
            if cloud == .cloud115 {
                selectedCid = "0"
                selectedName = "根目录"
            }
            isLoading = true
            client = await servicesStore.cloudsaverClient(instanceId: instanceId)
            isLoading = false
            if client == nil {
                error = "服务未就绪，请确认 CloudSaver 已登录"
            } else {
                await load("0")
            }
        }
    }

    private func load(_ parent: String) async {
        guard let client else {
            error = "服务未就绪，请确认 CloudSaver 已登录"
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            folders = try await client.listFolders(cloud: cloud, parentCid: parent)
        } catch {
            folders = []
            self.error = CloudSaverUserFacingError.message(from: error)
        }
    }
}
