import SwiftUI

/// Full-screen push detail — back returns to search/list.
struct CloudSaverDetailView: View {
    let instanceId: UUID
    let item: CloudSaverSearchResult

    @Environment(ServicesStore.self) private var servicesStore
    @Environment(\.openURL) private var openURL

    @State private var client: CloudSaverAPIClient?
    @State private var settings: CloudSaverSettings = .empty
    @State private var health: CloudSaverLinkHealth = .unknown
    @State private var files: [CloudSaverShareFile] = []
    @State private var resolvedReceiveCode: String = ""
    @State private var isSaving = false
    @State private var isTransferred = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    @State private var browseFolders: [CloudSaverRemoteFolder] = []
    @State private var browseStack: [CloudSaverRemoteFolder] = []
    @State private var isLoadingFolders = false
    @State private var folderError: String?
    @State private var selectedBrowseCid: String = ""
    @State private var selectedBrowseName: String = ""

    @State private var imageBaseURL = ""
    @State private var imageToken = ""
    @State private var imageAllowSelfSigned = true
    @State private var showPathSheet = false
    @State private var toastMessage: String?

    private var accent: Color { ServiceType.cloudsaver.colors.primary }

    private var currentParentCid: String { browseStack.last?.cid ?? "0" }

    private var selectedFolderId: String {
        selectedBrowseCid.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedFolderLabel: String {
        if selectedBrowseCid.isEmpty {
            return "未选择（请点选文件夹）"
        }
        if selectedBrowseCid == "0" {
            return selectedBrowseName.isEmpty ? "根目录" : selectedBrowseName
        }
        return selectedBrowseName.isEmpty ? selectedBrowseCid : selectedBrowseName
    }

    private var defaultFolderSummary: String {
        if let d = settings.defaultFolder(for: item.cloudType) {
            return "\(d.name)（\(d.cid)）"
        }
        return "未设置（可在下方选目录后设为默认，或到设置中选择）"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                metaSection
                linkSection
                healthBanner
                filesPreviewSection
                actionButtons
                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? .red : AppTheme.textSecondary)
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("资源详情")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }
        }
        .animation(.spring(duration: 0.3), value: toastMessage)
        .sheet(isPresented: $showPathSheet) {
            NavigationStack {
                savePathSheet
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            settings = CloudSaverSettingsStore.load(instanceId: instanceId)
            if let instance = servicesStore.instance(id: instanceId) {
                imageBaseURL = instance.url
                imageToken = instance.token.isEmpty ? (instance.apiKey ?? "") : instance.token
                imageAllowSelfSigned = instance.allowSelfSigned
            }
            client = await servicesStore.cloudsaverClient(instanceId: instanceId)
            applyDefaultFolderSelection()
            await checkLink()
        }
    }

    // MARK: - Header / link / health (unchanged structure)

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 14) {
            CloudSaverRemoteImage(
                urlString: item.imageURL,
                serviceBaseURL: imageBaseURL,
                bearerToken: imageToken,
                allowSelfSigned: imageAllowSelfSigned
            )
            .frame(width: 110, height: 165)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Label(item.cloudType.displayName, systemImage: "externaldrive")
                    .font(.subheadline)
                    .foregroundStyle(accent)
                if !item.fileSize.isEmpty {
                    Text(item.fileSize)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                if !item.channel.isEmpty {
                    Text("来源：\(item.channel)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !item.pubDate.isEmpty {
                Label("搜索/发布时间：\(item.pubDate)", systemImage: "clock")
            }
            if !item.channel.isEmpty {
                Label("来源频道：\(item.channel)", systemImage: "antenna.radiowaves.left.and.right")
            }
            if item.count > 1 {
                Label("聚合结果：\(item.count) 条", systemImage: "square.stack.3d.up")
            }
            if let dest = settings.defaultFolder(for: item.cloudType) {
                Label("默认保存：\(dest.name)", systemImage: "star")
            }
        }
        .font(.caption)
        .foregroundStyle(AppTheme.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分享链接")
                .font(.subheadline.weight(.semibold))

            Text(item.shareURL)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = item.shareURL
                    statusMessage = "链接已复制"
                    statusIsError = false
                } label: {
                    Label("复制链接", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let url = URL(string: item.shareURL), item.cloudType != .unknown {
                    Button {
                        openURL(url)
                    } label: {
                        Label("浏览器打开", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("分享码：")
                    Text(item.shareCode).textSelection(.enabled)
                    Spacer()
                }
                if !item.receiveCode.isEmpty {
                    HStack {
                        Text("提取码：")
                        Text(item.receiveCode).textSelection(.enabled)
                        Spacer()
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textMuted)
        }
    }

    @ViewBuilder
    private var healthBanner: some View {
        HStack(spacing: 8) {
            switch health {
            case .checking:
                ProgressView()
                Text("正在检测链接…")
            case .unknown:
                Image(systemName: "link")
                Text("未检测")
            case .valid(let n):
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("链接有效（\(n) 个文件）").foregroundStyle(.green)
            case .invalid(let m):
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text("链接失效：\(m)").foregroundStyle(.red)
            }
        }
        .font(.subheadline.weight(.medium))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Path (browse / preset / custom)

    private var filesPreviewSection: some View {
        Group {
            if !files.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("分享内文件")
                        .font(.subheadline.weight(.semibold))
                    ForEach(files.prefix(8)) { f in
                        HStack {
                            Image(systemName: (f.isFolder == true) ? "folder.fill" : "doc")
                                .foregroundStyle(AppTheme.textMuted)
                            Text(f.fileName.isEmpty ? f.fileId : f.fileName)
                                .font(.caption)
                                .lineLimit(2)
                            Spacer()
                        }
                    }
                    if files.count > 8 {
                        Text("…共 \(files.count) 个（保存时再选目录）")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .padding(12)
                .background(AppTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if item.cloudType == .cloud115 {
                Button {
                    Task { await wantToWatch115() }
                } label: {
                    Label("想看（默认目录）", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(isSaving || isTransferred || health.isInvalid || settings.defaultFolder(for: .cloud115) == nil)
            }

            Button {
                applyDefaultFolderSelection()
                showPathSheet = true
                if item.cloudType != .unknown {
                    Task { await loadFolders(parentCid: currentParentCid) }
                }
            } label: {
                HStack {
                    if isSaving { ProgressView() }
                    Text(isTransferred ? "已保存" : "选择目录并保存")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent.opacity(item.cloudType == .cloud115 ? 0.85 : 1))
            .disabled(isSaving || isTransferred || health.isInvalid)
        }
    }

    private var savePathSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("选择保存目录")
                    .font(.headline)
                Text("目录从网盘接口加载。Cookie 过期请到 CloudSaver 网页刷新。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let d = settings.defaultFolder(for: item.cloudType) {
                    Button {
                        selectedBrowseCid = d.cid
                        selectedBrowseName = d.name
                    } label: {
                        Label("使用默认：\(d.name)", systemImage: "star.fill")
                    }
                }

                Text("当前：\(selectedFolderLabel)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .textSelection(.enabled)

                folderBrowser

                if !selectedBrowseCid.isEmpty, !(item.cloudType == .quark && selectedBrowseCid == "0") {
                    Button {
                        settings.setDefaultFolder(cloud: item.cloudType, cid: selectedBrowseCid, name: selectedFolderLabel)
                        CloudSaverSettingsStore.save(settings, instanceId: instanceId)
                        statusMessage = "已设为默认目录"
                        statusIsError = false
                    } label: {
                        Label("将当前目录设为默认", systemImage: "star")
                            .font(.caption)
                    }
                }

                Button {
                    Task {
                        await save()
                        if isTransferred {
                            showPathSheet = false
                        }
                    }
                } label: {
                    HStack {
                        if isSaving { ProgressView() }
                        Text(saveTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(isSaving || isTransferred || !canSaveWithSelectedFolder)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? .red : AppTheme.textSecondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("保存到网盘")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { showPathSheet = false }
            }
        }
    }

    private var folderBrowser: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Button("根目录") {
                        browseStack = []
                        if item.cloudType == .cloud115 {
                            selectedBrowseCid = "0"
                            selectedBrowseName = "根目录"
                        } else {
                            selectedBrowseCid = ""
                            selectedBrowseName = ""
                        }
                        Task { await loadFolders(parentCid: "0") }
                    }
                    .font(.caption.weight(.semibold))

                    ForEach(Array(browseStack.enumerated()), id: \.element.cid) { index, folder in
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textMuted)
                        Button(folder.name) {
                            browseStack = Array(browseStack.prefix(index + 1))
                            selectedBrowseCid = folder.cid
                            selectedBrowseName = browseStack.map(\.name).joined(separator: " / ")
                            Task { await loadFolders(parentCid: folder.cid) }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }

            if isLoadingFolders {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("加载目录…").font(.caption)
                }
            } else if let folderError {
                Text(folderError)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("重试") {
                    Task { await loadFolders(parentCid: currentParentCid) }
                }
                .font(.caption)
            } else if browseFolders.isEmpty {
                Text("此目录下没有子文件夹")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(browseFolders) { folder in
                        HStack(spacing: 10) {
                            Button {
                                selectedBrowseCid = folder.cid
                                selectedBrowseName = folderPathLabel(endingWith: folder)
                            } label: {
                                HStack {
                                    Image(systemName: selectedBrowseCid == folder.cid ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedBrowseCid == folder.cid ? accent : AppTheme.textMuted)
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.orange)
                                    Text(folder.name)
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                browseStack.append(folder)
                                selectedBrowseCid = folder.cid
                                selectedBrowseName = folderPathLabel(endingWith: folder)
                                Task { await loadFolders(parentCid: folder.cid) }
                            } label: {
                                Image(systemName: "chevron.right.circle")
                                    .foregroundStyle(accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .padding(.horizontal, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !selectedBrowseCid.isEmpty {
                Text("已选 CID：\(selectedBrowseCid)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(AppTheme.textMuted)
                    .textSelection(.enabled)
            }

            Button {
                Task { await loadFolders(parentCid: currentParentCid) }
            } label: {
                Label("刷新目录", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
        }
    }

    /// 115 allows folderId "0" (root); Quark requires a non-root cid.
    private var canSaveWithSelectedFolder: Bool {
        let id = selectedFolderId
        if id.isEmpty { return false }
        if id == "0" { return item.cloudType == .cloud115 }
        return true
    }

    private var saveTitle: String {
        if isTransferred { return "已保存" }
        if isSaving { return "保存中…" }
        if health.isInvalid { return "链接失效，无法保存" }
        if !canSaveWithSelectedFolder {
            if item.cloudType == .quark {
                return "请选择保存文件夹（不能选根目录）"
            }
            return "请选择保存文件夹"
        }
        return "保存到网盘"
    }

    // MARK: - Logic

    private func folderPathLabel(endingWith folder: CloudSaverRemoteFolder) -> String {
        (browseStack.map(\.name) + [folder.name]).joined(separator: " / ")
    }

    private func applyDefaultFolderSelection() {
        if let d = settings.defaultFolder(for: item.cloudType) {
            selectedBrowseCid = d.cid
            selectedBrowseName = d.name
        } else if item.cloudType == .cloud115 {
            selectedBrowseCid = "0"
            selectedBrowseName = "根目录"
        }
    }

    /// 115 only — same path as dashboard 想看.
    private func wantToWatch115() async {
        guard item.cloudType == .cloud115 else { return }
        guard let dest = settings.defaultFolder(for: .cloud115) else {
            statusMessage = "请先选择默认保存目录（浏览后点「设为默认」）"
            statusIsError = true
            return
        }
        selectedBrowseCid = dest.cid
        selectedBrowseName = dest.name
        await save()
        if isTransferred {
            let hint = settings.ingestHint.trimmingCharacters(in: .whitespacesAndNewlines)
            let msg: String
            if hint.isEmpty {
                msg = "想看成功：已保存到「\(dest.name)」"
            } else {
                msg = "想看成功：已保存到「\(dest.name)」。\(hint)"
            }
            statusMessage = msg
            // save() already shows toast on success
        }
    }

    private func loadFolders(parentCid: String) async {
        guard let client else {
            folderError = "服务未就绪"
            return
        }
        guard item.cloudType != .unknown else {
            folderError = "未知云盘类型"
            return
        }
        isLoadingFolders = true
        folderError = nil
        defer { isLoadingFolders = false }
        do {
            browseFolders = try await client.listFolders(cloud: item.cloudType, parentCid: parentCid)
        } catch {
            browseFolders = []
            folderError = CloudSaverUserFacingError.message(from: error)
        }
    }

    private func checkLink() async {
        guard let client else {
            health = .invalid("服务未就绪")
            return
        }
        if item.shareCode.isEmpty {
            health = .invalid("无分享码")
            return
        }
        if item.cloudType == .unknown {
            health = .invalid("未知云盘类型")
            return
        }
        health = .checking
        do {
            let info = try await client.shareInfo(
                shareCode: item.shareCode,
                receiveCode: item.receiveCode,
                cloud: item.cloudType
            )
            files = info.files
            resolvedReceiveCode = info.receiveCode
            health = info.files.isEmpty ? .invalid("分享无文件或已失效") : .valid(fileCount: info.files.count)
        } catch {
            health = .invalid(CloudSaverUserFacingError.message(from: error))
            files = []
            resolvedReceiveCode = ""
        }
    }

    private func save() async {
        guard let client else {
            statusMessage = "服务未就绪"
            statusIsError = true
            return
        }
        let folderId = selectedFolderId
        guard canSaveWithSelectedFolder else {
            statusMessage = item.cloudType == .quark
                ? "请选择具体文件夹（夸克不能选根目录）"
                : "请选择保存文件夹"
            statusIsError = true
            return
        }
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }
        do {
            var list = files
            var recv = resolvedReceiveCode.isEmpty ? item.receiveCode : resolvedReceiveCode
            if list.isEmpty {
                let info = try await client.shareInfo(
                    shareCode: item.shareCode,
                    receiveCode: item.receiveCode,
                    cloud: item.cloudType
                )
                list = info.files
                files = info.files
                resolvedReceiveCode = info.receiveCode
                recv = info.receiveCode
            }
            try await client.save(
                shareCode: item.shareCode,
                receiveCode: recv,
                cloud: item.cloudType,
                folderId: folderId,
                files: list
            )
            let followUp = await client.triggerPostSavePluginIfNeeded(
                pluginId: settings.resolvedPostSavePluginId,
                result: item,
                folderId: folderId,
                folderName: selectedFolderLabel,
                files: list
            )
            isTransferred = true
            statusIsError = false
            var parts: [String] = ["保存成功：已保存到 \(selectedFolderLabel)"]
            if let suffix = followUp.userSuffix {
                parts.append(suffix)
            }
            let hint = settings.ingestHint.trimmingCharacters(in: .whitespacesAndNewlines)
            if !hint.isEmpty {
                parts.append(hint)
            }
            let msg = parts.joined(separator: "。")
            statusMessage = msg
            showToast(msg)
        } catch {
            statusIsError = true
            statusMessage = CloudSaverUserFacingError.message(from: error)
        }
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
