import Foundation

actor CloudSaverAPIClient {
    private let instanceId: UUID
    private var engine: BaseNetworkEngine
    private var storedAllowSelfSigned = true
    private var baseURL: String = ""
    private var fallbackURL: String = ""
    private var token: String = ""
    private var username: String = ""
    private var password: String = ""
    private var onTokenRefresh: (@Sendable (String) -> Void)?

    init(instanceId: UUID) {
        self.instanceId = instanceId
        self.engine = BaseNetworkEngine(serviceType: .cloudsaver, instanceId: instanceId)
    }

    func setTokenRefreshCallback(_ callback: @escaping @Sendable (String) -> Void) {
        onTokenRefresh = callback
    }

    func configure(
        url: String,
        token: String,
        fallbackUrl: String? = nil,
        username: String? = nil,
        password: String? = nil,
        allowSelfSigned: Bool? = nil
    ) {
        self.baseURL = Self.cleanURL(url)
        self.fallbackURL = Self.cleanURL(fallbackUrl ?? "")
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.password = password ?? ""
        if let allowSelfSigned {
            storedAllowSelfSigned = allowSelfSigned
        }
        engine = BaseNetworkEngine(
            serviceType: .cloudsaver,
            instanceId: instanceId,
            allowSelfSigned: storedAllowSelfSigned
        )
    }

    func ping() async -> Bool {
        guard !baseURL.isEmpty else { return false }
        do {
            // Validate the stored JWT (and re-login once if expired), not just non-empty token.
            let _: CSEnvelope<CSDoubanHotData> = try await authorizedEnvelope(
                path: "/api/douban/hot?type=%E5%85%A8%E9%83%A8&category=%E7%83%AD%E9%97%A8&api=movie&limit=1",
                method: "GET",
                timeout: 15
            )
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func authenticate(
        url: String,
        username: String,
        password: String,
        fallbackUrl: String? = nil,
        allowSelfSigned: Bool? = nil
    ) async throws -> String {
        configure(
            url: url,
            token: "",
            fallbackUrl: fallbackUrl,
            username: username,
            password: password,
            allowSelfSigned: allowSelfSigned
        )
        return try await loginAndStoreToken()
    }

    func search(keyword: String, lastMessageId: String?) async throws -> CloudSaverSearchPage {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return CloudSaverSearchPage(results: [], hasMore: false, lastMessageId: "")
        }

        var query: [String] = ["keyword=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)"]
        if let lastMessageId, !lastMessageId.isEmpty {
            let enc = lastMessageId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lastMessageId
            query.append("lastMessageId=\(enc)")
        }
        let path = "/api/search?\(query.joined(separator: "&"))"
        // Server fan-out to many channels often takes 7–10s+ (see CS docker logs).
        let envelope: CSEnvelope<CSSearchDataFlexible> = try await authorizedEnvelope(
            path: path,
            method: "GET",
            timeout: 60
        )
        guard envelope.success != false else {
            throw APIError.custom(envelope.message ?? "搜索失败")
        }
        return Self.parseSearch(envelope.data)
    }

    /// Real instance: GET /api/douban/hot?type=全部&category=热门&api=movie&limit=50
    func fetchDoubanHot(
        type: String = "全部",
        category: String = "热门",
        api: String = "movie",
        limit: Int = 50
    ) async throws -> [CloudSaverDoubanItem] {
        let qType = type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? type
        let qCat = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
        let qApi = api.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? api
        let path = "/api/douban/hot?type=\(qType)&category=\(qCat)&api=\(qApi)&limit=\(limit)"
        let envelope: CSEnvelope<CSDoubanHotData> = try await authorizedEnvelope(
            path: path,
            method: "GET"
        )
        guard envelope.success != false else {
            throw APIError.custom(envelope.message ?? "获取豆瓣榜单失败")
        }
        return Self.parseDouban(envelope.data)
    }

    func shareInfo(
        shareCode: String,
        receiveCode: String,
        cloud: CloudSaverCloudType
    ) async throws -> CloudSaverShareInfoResult {
        switch cloud {
        case .cloud115:
            let encShare = shareCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareCode
            let encRecv = receiveCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? receiveCode
            let path = "/api/cloud115/share-info?shareCode=\(encShare)&receiveCode=\(encRecv)"
            let envelope: CSEnvelope<CS115ShareData> = try await authorizedEnvelope(
                path: path,
                method: "GET",
                timeout: 30
            )
            guard envelope.success != false else {
                throw APIError.custom(envelope.message ?? "获取分享信息失败")
            }
            let files = (envelope.data?.list ?? []).map {
                CloudSaverShareFile(
                    fileId: $0.fileId ?? $0.fid ?? "",
                    fileName: $0.fileName ?? $0.name ?? "",
                    fileSize: $0.fileSize ?? $0.size,
                    fileIdToken: $0.fileIdToken,
                    isFolder: $0.isFolder
                )
            }.filter { !$0.fileId.isEmpty }
            return CloudSaverShareInfoResult(files: files, receiveCode: receiveCode)

        case .quark:
            let encShare = shareCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareCode
            let encRecv = receiveCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? receiveCode
            let path = "/api/quark/share-info?shareCode=\(encShare)&receiveCode=\(encRecv)"
            let envelope: CSEnvelope<CSQuarkShareData> = try await authorizedEnvelope(
                path: path,
                method: "GET",
                timeout: 30
            )
            guard envelope.success != false else {
                throw APIError.custom(envelope.message ?? "获取夸克分享信息失败")
            }
            let data = envelope.data
            let files = (data?.list ?? []).map {
                CloudSaverShareFile(
                    fileId: $0.fileId ?? $0.fid ?? "",
                    fileName: $0.fileName ?? $0.name ?? "",
                    fileSize: $0.fileSize ?? $0.size,
                    fileIdToken: $0.fileIdToken ?? $0.shareFidToken,
                    isFolder: $0.isFolder
                )
            }.filter { !$0.fileId.isEmpty }
            // Real save body uses long stoken as receiveCode (not pan link password).
            let resolved =
                (data?.stoken?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? (data?.receiveCode?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? receiveCode
            return CloudSaverShareInfoResult(files: files, receiveCode: resolved)

        case .unknown:
            throw APIError.custom("不支持的云盘类型")
        }
    }

    /// GET /api/quark/folders?parentCid=  or /api/cloud115/folders?parentCid=
    /// Root uses parentCid=0 (web default).
    func listFolders(
        cloud: CloudSaverCloudType,
        parentCid: String = "0"
    ) async throws -> [CloudSaverRemoteFolder] {
        let parent = parentCid.trimmingCharacters(in: .whitespacesAndNewlines)
        let cid = parent.isEmpty ? "0" : parent
        let enc = cid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cid
        let path: String
        switch cloud {
        case .quark:
            path = "/api/quark/folders?parentCid=" + enc
        case .cloud115:
            path = "/api/cloud115/folders?parentCid=" + enc
        case .unknown:
            throw APIError.custom("不支持的云盘类型")
        }
        let envelope: CSEnvelope<CSFolderListData> = try await authorizedEnvelope(
            path: path,
            method: "GET",
            timeout: 30
        )
        if envelope.success == false {
            throw APIError.custom(envelope.message ?? "获取目录失败")
        }
        let rows = envelope.data?.items ?? []
        let mapped = rows.compactMap { row -> CloudSaverRemoteFolder? in
            let cid = (row.cid ?? row.fileId ?? row.fid ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (row.name ?? row.fileName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cid.isEmpty else { return nil }
            return CloudSaverRemoteFolder(cid: cid, name: name.isEmpty ? cid : name)
        }
        // Empty list is valid (no subfolders). Do not assume Cookie failure.
        return mapped
    }

    /// POST /api/quark/save or /api/cloud115/save
    /// Quark body shape (verified): { fids, fidTokens, folderId, shareCode, receiveCode }
    /// where receiveCode is typically the long stoken from share-info; folderId is target cid.
    func save(
        shareCode: String,
        receiveCode: String,
        cloud: CloudSaverCloudType,
        folderId: String,
        files: [CloudSaverShareFile]
    ) async throws {
        let folder = folderId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folder.isEmpty else {
            throw APIError.custom("请选择保存文件夹")
        }
        if cloud == .quark, folder == "0" {
            throw APIError.custom("夸克不能保存到根目录，请选择子文件夹")
        }

        // Keep fids and fidTokens index-aligned (filter only empty fids).
        var fids: [String] = []
        var fidTokens: [String] = []
        for file in files {
            let fid = file.fileId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fid.isEmpty else { continue }
            fids.append(fid)
            fidTokens.append((file.fileIdToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard !fids.isEmpty else {
            throw APIError.custom("未找到可转存的文件")
        }

        switch cloud {
        case .cloud115:
            // Real body (verified): shareCode, receiveCode, fileId, folderId, fids
            // folderId may be "0" for 115 root; fileId mirrors first fid.
            let body: [String: Any] = [
                "shareCode": shareCode,
                "receiveCode": receiveCode,
                "fileId": fids[0],
                "folderId": folder,
                "fids": fids
            ]
            let data = try JSONSerialization.data(withJSONObject: body)
            let envelope: CSEnvelope<CS115SaveData> = try await authorizedEnvelope(
                path: "/api/cloud115/save",
                method: "POST",
                body: data,
                timeout: 60
            )
            // Prefer envelope.success; if CS wraps raw 115 payload in data, accept data presence.
            if envelope.success == false {
                throw APIError.custom(envelope.message ?? "转存失败")
            }

        case .quark:
            // Real CS expects non-empty parallel fidTokens (shareFidToken).
            if fidTokens.contains(where: { $0.isEmpty }) {
                throw APIError.custom("缺少夸克文件 token（shareFidToken），请重新检测链接")
            }
            let body: [String: Any] = [
                "fids": fids,
                "fidTokens": fidTokens,
                "folderId": folder,
                "shareCode": shareCode,
                "receiveCode": receiveCode
            ]
            let data = try JSONSerialization.data(withJSONObject: body)
            let envelope: CSEnvelope<CSEmptyData> = try await authorizedEnvelope(
                path: "/api/quark/save",
                method: "POST",
                body: data,
                timeout: 60
            )
            guard envelope.success != false else {
                throw APIError.custom(envelope.message ?? "夸克转存失败")
            }

        case .unknown:
            throw APIError.custom("不支持的云盘类型")
        }
    }

    /// End-to-end want-to-watch: share-info + save into folder, then optional plugin hooks.
    /// Plugin failure does **not** throw after a successful save — check `CloudSaverPostSaveFollowUp`.
    @discardableResult
    func wantToWatch(
        result: CloudSaverSearchResult,
        folderId: String,
        folderName: String = "",
        postSavePluginId: Int? = nil
    ) async throws -> CloudSaverPostSaveFollowUp {
        let info = try await shareInfo(
            shareCode: result.shareCode,
            receiveCode: result.receiveCode,
            cloud: result.cloudType
        )
        try await save(
            shareCode: result.shareCode,
            receiveCode: info.receiveCode,
            cloud: result.cloudType,
            folderId: folderId,
            files: info.files
        )
        return await triggerPostSavePluginIfNeeded(
            pluginId: postSavePluginId,
            result: result,
            folderId: folderId,
            folderName: folderName,
            files: info.files
        )
    }

    /// After a successful `save`, optionally `POST /api/plugins/run` (LitePan hooks → STRM / Emby).
    @discardableResult
    func triggerPostSavePluginIfNeeded(
        pluginId: Int?,
        result: CloudSaverSearchResult,
        folderId: String,
        folderName: String,
        files: [CloudSaverShareFile]
    ) async -> CloudSaverPostSaveFollowUp {
        guard let pluginId, pluginId > 0 else { return .skipped }
        let pathLabel = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = CloudSaverPluginBuiltInParams.make(
            result: result,
            saveFolderId: folderId,
            savePath: pathLabel.isEmpty ? folderId : pathLabel,
            files: files
        )
        do {
            let message = try await runPlugin(id: pluginId, params: params)
            return .triggered(message: message)
        } catch {
            let msg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return .failed(message: msg)
        }
    }

    /// `POST /api/plugins/run` — triggers CloudSaver plugins (e.g. LitePan 自动保存 / hooks).
    @discardableResult
    func runPlugin(
        id: Int,
        params: CloudSaverPluginBuiltInParams
    ) async throws -> String {
        let builtIn: [String: String] = [
            "title": params.title,
            "firstShareUrl": params.firstShareUrl,
            "shareUrlStr": params.shareUrlStr,
            "description": params.description,
            "shareUrl": params.shareUrl,
            "shareTitle": params.shareTitle,
            "savePath": params.savePath,
            "saveFid": params.saveFid,
            "shareFid": params.shareFid
        ]
        let bodyObj: [String: Any] = [
            "id": id,
            "builtInParams": builtIn
        ]
        let data = try JSONSerialization.data(withJSONObject: bodyObj)
        let envelope: CSEnvelope<CSPluginRunData> = try await authorizedEnvelope(
            path: "/api/plugins/run",
            method: "POST",
            body: data,
            timeout: 60
        )
        if envelope.success == false {
            throw APIError.custom(envelope.message ?? "插件触发失败")
        }
        // Prefer outer message (e.g. "LitePan推送触发成功！"), then nested.
        let outer = (envelope.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !outer.isEmpty { return outer }
        let nested = (envelope.data?.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !nested.isEmpty { return nested }
        if let names = envelope.data?.triggeredNames, !names.isEmpty {
            return "已触发：\(names.joined(separator: "、"))"
        }
        return "LitePan推送触发成功"
    }

    // MARK: - Private

    private var canPasswordLogin: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private func authHeaders(_ token: String) -> [String: String] {
        ["Authorization": "Bearer \(token)", "Content-Type": "application/json"]
    }

    private func ensureToken() async throws -> String {
        if !token.isEmpty { return token }
        return try await loginAndStoreToken()
    }

    /// Authenticated request with one automatic password re-login when the App JWT/session expired.
    private func authorizedEnvelope<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> CSEnvelope<T> {
        do {
            return try await performAuthorizedEnvelope(
                path: path,
                method: method,
                body: body,
                timeout: timeout
            )
        } catch {
            guard CloudSaverAuthFailure.isAppSessionAuthError(error), canPasswordLogin else { throw error }
            token = ""
            _ = try await loginAndStoreToken()
            return try await performAuthorizedEnvelope(
                path: path,
                method: method,
                body: body,
                timeout: timeout
            )
        }
    }

    private func performAuthorizedEnvelope<T: Decodable>(
        path: String,
        method: String,
        body: Data?,
        timeout: TimeInterval?
    ) async throws -> CSEnvelope<T> {
        let jwt = try await ensureToken()
        let envelope: CSEnvelope<T> = try await engine.request(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: path,
            method: method,
            headers: authHeaders(jwt),
            body: body,
            timeout: timeout
        )
        // Some CS builds return HTTP 200 + success:false instead of 401 when JWT is stale.
        if envelope.success == false,
           let message = envelope.message,
           CloudSaverAuthFailure.looksLikeAppSession(message) {
            throw APIError.unauthorized
        }
        return envelope
    }


    @discardableResult
    private func loginAndStoreToken() async throws -> String {
        guard canPasswordLogin else {
            throw APIError.unauthorized
        }
        let body = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password
        ])
        let envelope: CSEnvelope<CSLoginData> = try await engine.request(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: "/api/user/login",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: body
        )
        guard envelope.success != false,
              let jwt = envelope.data?.token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !jwt.isEmpty
        else {
            let msg = (envelope.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if msg.isEmpty {
                throw APIError.unauthorized
            }
            throw APIError.custom(msg)
        }
        token = jwt
        onTokenRefresh?(jwt)
        return jwt
    }

    private static func cleanURL(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }


    private static func parseDouban(_ data: CSDoubanHotData?) -> [CloudSaverDoubanItem] {
        guard let data else { return [] }
        return data.items.compactMap { row in
            let id = row.id ?? ""
            let title = row.title ?? ""
            guard !id.isEmpty || !title.isEmpty else { return nil }
            let cover = row.pic?.normal ?? row.pic?.large ?? row.cover ?? ""
            let rate: String
            if let v = row.rating?.value {
                // Prefer one decimal when needed
                if v == floor(v) {
                    rate = String(Int(v))
                } else {
                    rate = String(format: "%.1f", v)
                }
            } else if let s = row.rate, !s.isEmpty {
                rate = s
            } else {
                rate = ""
            }
            let subtitle = row.card_subtitle ?? row.cardSubtitle ?? ""
            let isNew = row.is_new ?? row.isNew ?? false
            let ratingCount = row.rating?.count ?? 0
            let honor = (row.honor ?? row.honor_info ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let honorTag = honor.isEmpty ? CloudSaverDoubanItem.honorTag(forRate: rate, isNew: isNew) : honor
            return CloudSaverDoubanItem(
                id: id.isEmpty ? title : id,
                title: title,
                rate: rate,
                cover: cover,
                url: row.url ?? row.uri ?? "",
                subtitle: subtitle,
                isNew: isNew,
                ratingCount: ratingCount,
                honorTag: honorTag,
                reputation: CloudSaverDoubanItem.reputation(forRate: rate),
                year: CloudSaverDoubanItem.year(from: subtitle)
            )
        }
    }

    private static func parseSearch(_ data: CSSearchDataFlexible?) -> CloudSaverSearchPage {
        guard let data else {
            return CloudSaverSearchPage(results: [], hasMore: false, lastMessageId: "")
        }

        // Already flattened shape (proxy-style)
        if let flat = data.results, !flat.isEmpty {
            let mapped = flat.compactMap(mapFlatResult)
            return CloudSaverSearchPage(
                results: mergeByShareCode(mapped),
                hasMore: data.hasMore ?? false,
                lastMessageId: data.lastMessageId ?? data.nextMessageId ?? ""
            )
        }

        // CloudSaver native: channels with list + cloudLinks
        let channels = data.channels ?? data.rawChannels ?? []
        var raw: [CloudSaverSearchResult] = []
        var hasMore = false
        var lastId = ""
        for channel in channels {
            if channel.hasMore == true {
                hasMore = true
                lastId = channel.nextMessageId ?? lastId
            }
            for item in channel.list ?? [] {
                let title = cleanHTML(item.title ?? "")
                let description = cleanHTML(item.content ?? item.description ?? "")
                let image = item.image ?? ""
                let links = item.cloudLinks ?? []
                for link in links {
                    let linkStr: String
                    let cloudRaw: String
                    if let s = link.stringValue {
                        linkStr = s
                        cloudRaw = ""
                    } else {
                        linkStr = link.link ?? ""
                        cloudRaw = link.cloudType ?? ""
                    }
                    guard !linkStr.isEmpty, let parsed = parseShareLink(linkStr) else { continue }
                    raw.append(
                        CloudSaverSearchResult(
                            title: title,
                            description: description,
                            imageURL: image,
                            shareCode: parsed.shareCode,
                            receiveCode: parsed.receiveCode,
                            cloudType: CloudSaverCloudType(parsing: cloudRaw.isEmpty ? linkStr : cloudRaw),
                            fileSize: extractFileSize(description),
                            channel: item.channel ?? channel.channelInfo?.name ?? "",
                            channelId: item.channelId ?? channel.id ?? "",
                            pubDate: item.pubDate ?? "",
                            messageId: item.messageId ?? "",
                            tags: item.tags ?? [],
                            count: 1
                        )
                    )
                    break
                }
            }
        }
        return CloudSaverSearchPage(
            results: mergeByShareCode(raw),
            hasMore: hasMore,
            lastMessageId: lastId
        )
    }

    private static func mapFlatResult(_ item: CSFlatResult) -> CloudSaverSearchResult? {
        let share = item.shareCode ?? ""
        guard !share.isEmpty else { return nil }
        return CloudSaverSearchResult(
            title: cleanHTML(item.title ?? ""),
            description: cleanHTML(item.description ?? ""),
            imageURL: item.image ?? "",
            shareCode: share,
            receiveCode: item.receiveCode ?? "",
            cloudType: CloudSaverCloudType(parsing: item.cloudType ?? ""),
            fileSize: item.fileSize ?? "",
            channel: item.channel ?? "",
            channelId: item.channelId ?? "",
            pubDate: item.pubDate ?? "",
            messageId: item.messageId ?? "",
            tags: item.tags ?? [],
            count: item.count ?? 1
        )
    }

    private static func mergeByShareCode(_ items: [CloudSaverSearchResult]) -> [CloudSaverSearchResult] {
        var map: [String: CloudSaverSearchResult] = [:]
        var order: [String] = []
        for item in items {
            if var existing = map[item.shareCode] {
                existing.count += 1
                if existing.imageURL.isEmpty, !item.imageURL.isEmpty {
                    existing = CloudSaverSearchResult(
                        title: existing.title,
                        description: existing.description.isEmpty ? item.description : existing.description,
                        imageURL: item.imageURL,
                        shareCode: existing.shareCode,
                        receiveCode: existing.receiveCode,
                        cloudType: existing.cloudType == .unknown ? item.cloudType : existing.cloudType,
                        fileSize: existing.fileSize.isEmpty ? item.fileSize : existing.fileSize,
                        channel: existing.channel,
                        channelId: existing.channelId,
                        pubDate: existing.pubDate,
                        messageId: existing.messageId,
                        tags: existing.tags,
                        count: existing.count
                    )
                }
                map[item.shareCode] = existing
            } else {
                map[item.shareCode] = item
                order.append(item.shareCode)
            }
        }
        return order.compactMap { map[$0] }
    }

    private static func parseShareLink(_ link: String) -> (shareCode: String, receiveCode: String)? {
        if let regex = try? NSRegularExpression(pattern: #"(?:115|anxia|115cdn)\.com/s/([^?]+)(?:\?password=([^&#]+))?"#),
           let match = regex.firstMatch(in: link, range: NSRange(link.startIndex..., in: link)),
           let codeRange = Range(match.range(at: 1), in: link) {
            let code = String(link[codeRange])
            var recv = ""
            if match.numberOfRanges > 2, let r = Range(match.range(at: 2), in: link) {
                recv = String(link[r])
            }
            return (code, recv)
        }
        if let regex = try? NSRegularExpression(pattern: #"pan\.quark\.cn/s/([a-zA-Z0-9]+)"#),
           let match = regex.firstMatch(in: link, range: NSRange(link.startIndex..., in: link)),
           let codeRange = Range(match.range(at: 1), in: link) {
            return (String(link[codeRange]), "")
        }
        return nil
    }

    private static func cleanHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractFileSize(_ content: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(GB|MB|TB|KB)"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let n = Range(match.range(at: 1), in: content),
              let u = Range(match.range(at: 2), in: content)
        else { return "" }
        return "\(content[n]) \(content[u].uppercased())"
    }
}

// MARK: - Wire DTOs

private struct CSEnvelope<T: Decodable>: Decodable {
    let success: Bool?
    let message: String?
    let data: T?
}

private struct CSLoginData: Decodable {
    let token: String?
}

private struct CSEmptyData: Decodable {}

/// Flexible decode for `/api/plugins/run` nested LitePan payload.
private struct CSPluginRunData: Decodable {
    let success: Bool?
    let message: String?
    let data: CSPluginRunInner?

    var triggeredNames: [String]? {
        data?.triggered?.compactMap { t in
            let n = (t.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return n.isEmpty ? nil : n
        }
    }
}

private struct CSPluginRunInner: Decodable {
    let event: String?
    let matched: Int?
    let path: String?
    let source: String?
    let triggered: [CSPluginTriggered]?
}

private struct CSPluginTriggered: Decodable {
    let id: Int?
    let name: String?
}

private struct CSSearchDataFlexible: Decodable {
    let results: [CSFlatResult]?
    let hasMore: Bool?
    let lastMessageId: String?
    let nextMessageId: String?
    // Native channel array may be root of `data`
    let channels: [CSChannel]?
    // When data itself is array — handled via raw decode fallback
    var rawChannels: [CSChannel]? { channels }

    init(from decoder: Decoder) throws {
        if var unkeyed = try? decoder.unkeyedContainer() {
            var ch: [CSChannel] = []
            while !unkeyed.isAtEnd {
                if let c = try? unkeyed.decode(CSChannel.self) {
                    ch.append(c)
                } else {
                    _ = try? unkeyed.decode(CSJSONValue.self)
                }
            }
            results = nil
            hasMore = nil
            lastMessageId = nil
            nextMessageId = nil
            channels = ch
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        results = try c.decodeIfPresent([CSFlatResult].self, forKey: .results)
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore)
        lastMessageId = try c.decodeIfPresent(String.self, forKey: .lastMessageId)
        nextMessageId = try c.decodeIfPresent(String.self, forKey: .nextMessageId)
        if let ch = try c.decodeIfPresent([CSChannel].self, forKey: .channels) {
            channels = ch
        } else if let items = try c.decodeIfPresent([CSChannelItem].self, forKey: .list) {
            channels = [CSChannel(id: nil, hasMore: nil, nextMessageId: nil, list: items, channelInfo: nil)]
        } else {
            channels = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case results, hasMore, lastMessageId, nextMessageId, channels, list, data
    }
}

private struct CSFlatResult: Decodable {
    let title: String?
    let description: String?
    let image: String?
    let shareCode: String?
    let receiveCode: String?
    let cloudType: String?
    let fileSize: String?
    let channel: String?
    let channelId: String?
    let pubDate: String?
    let messageId: String?
    let tags: [String]?
    let count: Int?
}

private struct CSChannel: Decodable {
    let id: String?
    let hasMore: Bool?
    let nextMessageId: String?
    let list: [CSChannelItem]?
    let channelInfo: CSChannelInfo?

    init(id: String?, hasMore: Bool?, nextMessageId: String?, list: [CSChannelItem]?, channelInfo: CSChannelInfo?) {
        self.id = id
        self.hasMore = hasMore
        self.nextMessageId = nextMessageId
        self.list = list
        self.channelInfo = channelInfo
    }
}

private struct CSChannelInfo: Decodable {
    let name: String?
}

private struct CSChannelItem: Decodable {
    let title: String?
    let content: String?
    let description: String?
    let image: String?
    let channel: String?
    let channelId: String?
    let pubDate: String?
    let messageId: String?
    let tags: [String]?
    let cloudLinks: [CSCloudLink]?
}

private struct CSCloudLink: Decodable {
    let link: String?
    let cloudType: String?
    let stringValue: String?

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            link = nil
            cloudType = nil
            stringValue = s
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        link = try c.decodeIfPresent(String.self, forKey: .link)
        cloudType = try c.decodeIfPresent(String.self, forKey: .cloudType)
        stringValue = nil
    }

    private enum CodingKeys: String, CodingKey {
        case link, cloudType
    }
}

private struct CS115ShareData: Decodable {
    let list: [CSShareFileDTO]?
}

private struct CSQuarkShareData: Decodable {
    let list: [CSShareFileDTO]?
    let pwdId: String?
    let stoken: String?
    /// Some CS builds may surface receiveCode / token at data root.
    let receiveCode: String?
}

private struct CSShareFileDTO: Decodable {
    let fileId: String?
    let fid: String?
    let fileName: String?
    let name: String?
    let fileSize: Int?
    let size: Int?
    let fileIdToken: String?
    let shareFidToken: String?
    let isFolder: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileId = Self.stringish(c, .fileId)
        fid = Self.stringish(c, .fid)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        fileSize = try c.decodeIfPresent(Int.self, forKey: .fileSize)
            ?? c.decodeIfPresent(Int.self, forKey: .size).map { $0 }
        size = try c.decodeIfPresent(Int.self, forKey: .size)
        fileIdToken = try c.decodeIfPresent(String.self, forKey: .fileIdToken)
        shareFidToken = try c.decodeIfPresent(String.self, forKey: .shareFidToken)
        isFolder = try c.decodeIfPresent(Bool.self, forKey: .isFolder)
    }

    private static func stringish(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let n = try? c.decodeIfPresent(Int64.self, forKey: key) { return String(n) }
        if let n = try? c.decodeIfPresent(Int.self, forKey: key) { return String(n) }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case fileId, fid, fileName, name, fileSize, size, fileIdToken, shareFidToken, isFolder
    }
}

private enum CSJSONValue: Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([CSJSONValue])
    case object([String: CSJSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([CSJSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: CSJSONValue].self) { self = .object(o); return }
        self = .null
    }
}

/// GET /api/quark/folders?parentCid=  & /api/cloud115/folders?parentCid=
/// Real envelope: { success, code, data:[{cid,name,path:[]}], message }
private struct CSFolderListData: Decodable {
    let items: [CSFolderDTO]

    init(from decoder: Decoder) throws {
        // data is a JSON array of folders
        if var unkeyed = try? decoder.unkeyedContainer() {
            var rows: [CSFolderDTO] = []
            while !unkeyed.isAtEnd {
                if let row = try? unkeyed.decode(CSFolderDTO.self) {
                    rows.append(row)
                } else {
                    _ = try? unkeyed.decode(CSJSONValue.self)
                }
            }
            items = rows
            return
        }
        // Fallback object wrappers
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let rows = try c.decodeIfPresent([CSFolderDTO].self, forKey: .data) {
            items = rows
        } else if let rows = try c.decodeIfPresent([CSFolderDTO].self, forKey: .list) {
            items = rows
        } else if let rows = try c.decodeIfPresent([CSFolderDTO].self, forKey: .folders) {
            items = rows
        } else {
            items = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case data, list, folders
    }
}

/// Folder row from quark/115 folders API.
/// Quark: path often []; 115: path is objects [{name,cid,...}] — ignore structure, only need cid/name.
private struct CSFolderDTO: Decodable {
    let cid: String?
    let name: String?
    let fileId: String?
    let fid: String?
    let fileName: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try c.decodeIfPresent(String.self, forKey: .cid) {
            cid = s
        } else if let n = try c.decodeIfPresent(Int64.self, forKey: .cid) {
            cid = String(n)
        } else if let n = try c.decodeIfPresent(Int.self, forKey: .cid) {
            cid = String(n)
        } else {
            cid = nil
        }
        name = try c.decodeIfPresent(String.self, forKey: .name)
        if let s = try c.decodeIfPresent(String.self, forKey: .fileId) {
            fileId = s
        } else if let n = try c.decodeIfPresent(Int64.self, forKey: .fileId) {
            fileId = String(n)
        } else {
            fileId = nil
        }
        if let s = try c.decodeIfPresent(String.self, forKey: .fid) {
            fid = s
        } else if let n = try c.decodeIfPresent(Int64.self, forKey: .fid) {
            fid = String(n)
        } else {
            fid = nil
        }
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        // path: intentionally ignored (string[] or object[])
        _ = try? c.decodeIfPresent(CSJSONValue.self, forKey: .path)
    }

    private enum CodingKeys: String, CodingKey {
        case cid, name, path, fileId, fid, fileName
    }
}

/// Optional 115 save data payload (recv_file_count / receive_title / …)
private struct CS115SaveData: Decodable {
    let pid: Int?
    let recv_folder_count: Int?
    let recv_file_count: Int?
    let receive_title: String?
    let receive_size: Int64?
}

/// data: [ item... ]  (real CloudSaver response)
private struct CSDoubanHotData: Decodable {
    let items: [CSDoubanItemDTO]

    init(from decoder: Decoder) throws {
        // Envelope passes the `data` value which is a JSON array
        if var unkeyed = try? decoder.unkeyedContainer() {
            var rows: [CSDoubanItemDTO] = []
            while !unkeyed.isAtEnd {
                if let row = try? unkeyed.decode(CSDoubanItemDTO.self) {
                    rows.append(row)
                } else {
                    _ = try? unkeyed.decode(CSJSONValue.self)
                }
            }
            items = rows
            return
        }
        // Fallback object wrappers
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let rows = try c.decodeIfPresent([CSDoubanItemDTO].self, forKey: .data) {
            items = rows
        } else if let rows = try c.decodeIfPresent([CSDoubanItemDTO].self, forKey: .subjects) {
            items = rows
        } else if let rows = try c.decodeIfPresent([CSDoubanItemDTO].self, forKey: .list) {
            items = rows
        } else {
            items = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case data, subjects, list
    }
}

private struct CSDoubanPicDTO: Decodable {
    let large: String?
    let normal: String?
}

private struct CSDoubanRatingDTO: Decodable {
    let count: Int?
    let max: Int?
    let star_count: Double?
    let value: Double?
}

private struct CSDoubanItemDTO: Decodable {
    let id: String?
    let title: String?
    let pic: CSDoubanPicDTO?
    let rating: CSDoubanRatingDTO?
    let rate: String?
    let cover: String?
    let uri: String?
    let url: String?
    let card_subtitle: String?
    let cardSubtitle: String?
    let is_new: Bool?
    let isNew: Bool?
    let episodes_info: String?
    let type: String?
    let honor: String?
    let honor_info: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decodeIfPresent(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = nil
        }
        title = try c.decodeIfPresent(String.self, forKey: .title)
        pic = try c.decodeIfPresent(CSDoubanPicDTO.self, forKey: .pic)
        rating = try c.decodeIfPresent(CSDoubanRatingDTO.self, forKey: .rating)
        rate = try c.decodeIfPresent(String.self, forKey: .rate)
        cover = try c.decodeIfPresent(String.self, forKey: .cover)
        uri = try c.decodeIfPresent(String.self, forKey: .uri)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        card_subtitle = try c.decodeIfPresent(String.self, forKey: .card_subtitle)
        cardSubtitle = try c.decodeIfPresent(String.self, forKey: .cardSubtitle)
        is_new = try c.decodeIfPresent(Bool.self, forKey: .is_new)
        isNew = try c.decodeIfPresent(Bool.self, forKey: .isNew)
        episodes_info = try c.decodeIfPresent(String.self, forKey: .episodes_info)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        honor = try c.decodeIfPresent(String.self, forKey: .honor)
        honor_info = try c.decodeIfPresent(String.self, forKey: .honor_info)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, pic, rating, rate, cover, uri, url
        case card_subtitle, cardSubtitle, is_new, isNew, episodes_info, type
        case honor, honor_info
    }
}
