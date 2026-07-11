import Foundation

/// OpenList HTTP client (official API: fox.oplist.org).
/// Lists whatever the server exposes at the API root — no hardcoded mounts.
/// Auth: default username/password via `/api/auth/login`; optional pre-issued token.
actor OpenListAPIClient {
    private let instanceId: UUID
    private var engine: BaseNetworkEngine
    private var storedAllowSelfSigned = true
    private var baseURL: String = ""
    private var fallbackURL: String = ""
    private var token: String = ""
    private var username: String = ""
    private var password: String = ""
    /// From `/api/me` `base_path` — OpenList web joins this onto download/proxy paths.
    private var userBasePath: String = ""
    private var onTokenRefresh: (@Sendable (String) -> Void)?

    init(instanceId: UUID) {
        self.instanceId = instanceId
        self.engine = BaseNetworkEngine(serviceType: .openlist, instanceId: instanceId)
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
            serviceType: .openlist,
            instanceId: instanceId,
            allowSelfSigned: storedAllowSelfSigned
        )
    }

    func ping() async -> Bool {
        guard !baseURL.isEmpty else { return false }
        if token.isEmpty {
            guard !username.isEmpty, !password.isEmpty else { return false }
            do {
                _ = try await loginAndStoreToken()
            } catch {
                return false
            }
        }
        do {
            _ = try await me()
            return true
        } catch {
            // Session may have expired — try password login once
            if !username.isEmpty, !password.isEmpty {
                do {
                    _ = try await loginAndStoreToken()
                    _ = try await me()
                    return true
                } catch {
                    // Fall through to FS probe
                }
            }
            do {
                try await listRootForAuth()
                return true
            } catch {
                return false
            }
        }
    }

    /// Login with username/password (default). Returns JWT token.
    @discardableResult
    func authenticateWithCredentials(
        url: String,
        username: String,
        password: String,
        otpCode: String? = nil,
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
        return try await loginAndStoreToken(otpCode: otpCode)
    }

    /// Optional: paste an existing token instead of password login.
    func authenticateWithToken(
        url: String,
        token: String,
        fallbackUrl: String? = nil,
        allowSelfSigned: Bool? = nil
    ) async throws {
        configure(url: url, token: token, fallbackUrl: fallbackUrl, allowSelfSigned: allowSelfSigned)
        do {
            _ = try await me()
            return
        } catch {
            try await listRootForAuth()
        }
    }

    func me() async throws -> OpenListMeData {
        let data: OpenListMeData = try await getEnvelope(path: "/api/me", method: "GET", body: nil)
        // Match OpenList web: download/proxy links use pathJoin(me().base_path, dir)
        if let raw = data.base_path?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "/" {
            userBasePath = OpenListPath.normalize(raw)
        } else {
            userBasePath = ""
        }
        return data
    }

    /// List directory. `writable` comes from official `data.write` (server permissions).
    func list(path: String) async throws -> (items: [FileItem], writable: Bool) {
        let normalized = OpenListPath.normalize(path)
        let body = try JSONSerialization.data(withJSONObject: [
            "path": normalized,
            "password": "",
            "page": 1,
            "per_page": 0,
            "refresh": false
        ])
        let data: OpenListListData = try await getEnvelope(
            path: "/api/fs/list",
            method: "POST",
            body: body
        )
        let items = (data.content ?? []).map { FileItem.from(object: $0, parentPath: normalized, baseURL: baseURL) }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return (items, data.write == true)
    }

    /// Official: POST /api/fs/get.
    /// - playURL: always OpenList-hosted `/d…?sign=` for external players (avoid cloud CDN 403).
    /// - contentURL: prefer server `raw_url` when it is OpenList-hosted (`/p`/`/d` on our host);
    ///   else build `/p…?sign=` like OpenList web `proxyLink`.
    func detail(path: String) async throws -> FileDetail {
        try await ensureUserBasePathLoaded()
        let normalized = OpenListPath.normalize(path)
        let body = try JSONSerialization.data(withJSONObject: [
            "path": normalized,
            "password": ""
        ])
        let object: OpenListFsObject = try await getEnvelope(
            path: "/api/fs/get",
            method: "POST",
            body: body
        )
        let item = FileItem.from(detail: object, path: normalized, baseURL: baseURL)
        let sign = object.sign?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSign = (sign?.isEmpty == false) ? sign : nil
        let rawString = object.raw_url?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedRaw = (rawString?.isEmpty == false) ? rawString : nil

        guard !item.isDirectory else {
            return FileDetail(item: item, playURL: nil, contentURL: nil, sign: cleanedSign, serverRawURL: cleanedRaw)
        }

        // External play/copy: always host `/d` (sign auth). Never prefer CDN raw_url.
        let playURL = makeFileAccessURL(logicalPath: normalized, sign: cleanedSign, mode: .direct, joinBase: true)
            ?? makeFileAccessURL(logicalPath: normalized, sign: cleanedSign, mode: .direct, joinBase: false)

        // In-app content: OpenList-hosted raw_url first (server already built correct path+sign).
        let contentURL: URL?
        if let raw = cleanedRaw, let url = resolveOpenListHostedURL(raw) {
            contentURL = url
        } else {
            contentURL = makeFileAccessURL(logicalPath: normalized, sign: cleanedSign, mode: .proxy, joinBase: true)
                ?? makeFileAccessURL(logicalPath: normalized, sign: cleanedSign, mode: .proxy, joinBase: false)
        }

        return FileDetail(
            item: item,
            playURL: playURL,
            contentURL: contentURL,
            sign: cleanedSign,
            serverRawURL: cleanedRaw
        )
    }

    /// Load text for preview (md/txt/ass/html…).
    /// Prefer server-built OpenList-hosted URL (`raw_url` when it is `/p`/`/d` on our host).
    func fetchTextContent(path: String, using existingDetail: FileDetail? = nil, maxBytes: Int = 2_000_000) async throws -> String {
        let normalized = OpenListPath.normalize(path)
        let detail: FileDetail
        if let existingDetail, existingDetail.item.path == normalized {
            detail = existingDetail
        } else {
            detail = try await self.detail(path: normalized)
        }
        guard !baseURL.isEmpty else { throw APIError.notConfigured }

        AppLogger.shared.info(
            "textPreview path=\(normalized) base=\(baseURL) userBase=\(userBasePath.isEmpty ? "(empty)" : userBasePath) sign=\(detail.sign ?? "(none)") raw=\(detail.serverRawURL ?? "(none)") content=\(detail.contentURL?.absoluteString ?? "(none)")",
            source: "OpenList"
        )

        // Prefer exact server-hosted URL string (raw_url when /p on our host) — already proven OK for .nfo.
        var candidates: [URL] = []
        if let raw = detail.serverRawURL, let u = resolveOpenListHostedURL(raw) {
            candidates.append(u)
        }
        if let u = detail.contentURL { candidates.append(u) }
        if let u = makeFileAccessURL(logicalPath: normalized, sign: detail.sign, mode: .proxy, joinBase: true) {
            candidates.append(u)
        }
        if let u = makeFileAccessURL(logicalPath: normalized, sign: detail.sign, mode: .direct, joinBase: true) {
            candidates.append(u)
        }
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.absoluteString).inserted }
        AppLogger.shared.info("textPreview candidates=\(unique.count)", source: "OpenList")
        for (idx, u) in unique.enumerated() {
            AppLogger.shared.network("textPreview[\(idx)] \(u.absoluteString)", source: "OpenList")
        }

        var lastError: Error = APIError.custom("No preview URL")
        for (idx, url) in unique.enumerated() {
            do {
                let data = try await downloadFileBytes(from: url)
                AppLogger.shared.info(
                    "textPreview[\(idx)] OK bytes=\(data.count) url=\(url.absoluteString)",
                    source: "OpenList"
                )
                let limited = data.count > maxBytes ? data.prefix(maxBytes) : data[...]
                if let utf8 = String(data: Data(limited), encoding: .utf8) {
                    return utf8
                }
                if let latin1 = String(data: Data(limited), encoding: .isoLatin1) {
                    return latin1
                }
                throw APIError.custom("Unable to decode text preview")
            } catch {
                let desc: String
                if let api = error as? APIError {
                    desc = api.errorDescription ?? String(describing: api)
                } else {
                    desc = error.localizedDescription
                }
                AppLogger.shared.warn(
                    "textPreview[\(idx)] FAIL \(desc) url=\(url.absoluteString)",
                    source: "OpenList"
                )
                lastError = error
                continue
            }
        }
        AppLogger.shared.error("textPreview exhausted all candidates for \(normalized)", source: "OpenList")
        if let api = lastError as? APIError {
            throw api
        }
        throw APIError.custom(lastError.localizedDescription)
    }

    private enum FileAccessMode {
        case direct // /d — OpenList web rawLink (external)
        case proxy  // /p — OpenList web proxyLink (text preview)
    }

    /// Absolute OpenList file URL. Path is signed by server against JoinPath(base_path, path).
    private func makeFileAccessURL(
        logicalPath: String,
        sign: String?,
        mode: FileAccessMode,
        joinBase: Bool
    ) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        let serverPath = joinBase
            ? Self.joinUserBase(userBasePath, path: logicalPath)
            : OpenListPath.normalize(logicalPath)
        // OpenList server: utils.EncodePath(path, true) + prefix /p or /d
        let encoded = Self.encodeOpenListPath(serverPath, encodeAll: true)
        let prefix = (mode == .direct) ? "/d" : "/p"
        // String-build like OpenList-Frontend (avoid URLComponents re-encoding sign `=` → %3D).
        var urlString = baseURL
        if !urlString.hasSuffix("/") { /* base is cleaned without trailing slash */ }
        urlString += prefix + encoded
        if let sign, !sign.isEmpty {
            // Frontend: `ans += ?sign=${obj.sign}` literally.
            urlString += "?sign=" + sign
        }
        return URL(string: urlString)
    }

    /// Use server raw_url only when it is served by our OpenList host (`/p` or `/d`), not cloud CDN.
    private func resolveOpenListHostedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Relative OpenList paths
        if trimmed.hasPrefix("/p") || trimmed.hasPrefix("/d") {
            return URL(string: baseURL + (trimmed.hasPrefix("/") ? trimmed : "/" + trimmed))
        }
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else { return nil }
        guard let base = URL(string: baseURL), let baseHost = base.host else { return nil }
        guard host.caseInsensitiveCompare(baseHost) == .orderedSame else { return nil }
        let path = url.path
        // Allow /openlist/p/... subpath installs
        guard path.contains("/p/") || path.contains("/d/")
            || path.hasSuffix("/p") || path.hasPrefix("/p")
            || path.hasPrefix("/d") || path.contains("/p") || path.contains("/d")
        else { return nil }
        // Prefer path that actually has /p or /d segment
        let parts = path.split(separator: "/")
        guard parts.contains(where: { $0 == "p" || $0 == "d" }) else { return nil }
        return url
    }

    /// GET file bytes **without** Authorization.
    /// OpenList `/p`/`/d` only verify `sign` (`middlewares.Down`); JWT is not used.
    ///
    /// Uses a classic `dataTask` + continuation so SwiftUI task cancellation cannot
    /// abort mid-download (Designed for iPad logs: -999 cancelled, then late 200).
    private func downloadFileBytes(from url: URL) async throws -> Data {
        AppLogger.shared.network("--> GET \(url.absoluteString)", source: "OpenList")
        let allowSelfSigned = storedAllowSelfSigned
        let data: Data = try await withCheckedThrowingContinuation { cont in
            // Long-timeout session; dataTask is not aborted by SwiftUI task cancellation.
            let session = BaseNetworkEngine.authSession(allowSelfSigned: allowSelfSigned, timeout: 60)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 60
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    cont.resume(throwing: APIError.networkError(error))
                    return
                }
                guard let data, let http = response as? HTTPURLResponse else {
                    cont.resume(throwing: APIError.custom("Invalid download response"))
                    return
                }
                AppLogger.shared.network(
                    "<-- \(http.statusCode) \(url.absoluteString) (\(data.count) bytes)",
                    source: "OpenList"
                )
                guard (200...399).contains(http.statusCode) else {
                    let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
                    cont.resume(throwing: APIError.httpError(statusCode: http.statusCode, body: snippet))
                    return
                }
                cont.resume(returning: data)
            }
            task.resume()
        }
        return data
    }

    private func ensureUserBasePathLoaded() async throws {
        // base_path needed so signed /p path matches server JoinPath(user.BasePath, path)
        if token.isEmpty {
            if !username.isEmpty, !password.isEmpty {
                _ = try await loginAndStoreToken()
            }
            return
        }
        _ = try? await me()
    }

    private static func joinUserBase(_ base: String, path: String) -> String {
        // Mirror Go: stdpath.Join(FixAndCleanPath(basePath), FixAndCleanPath(reqPath))
        let baseNorm = OpenListPath.normalize(base.isEmpty ? "/" : base)
        let pathNorm = OpenListPath.normalize(path)
        if baseNorm == "/" { return pathNorm }
        if pathNorm == "/" { return baseNorm }
        return baseNorm + pathNorm
    }

    /// Mirrors OpenList `utils.EncodePath(path, true)` → PathEscape each segment.
    private static func encodeOpenListPath(_ path: String, encodeAll: Bool) -> String {
        let normalized = OpenListPath.normalize(path)
        if normalized == "/" { return "/" }
        let segments = normalized.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let encoded: [String] = segments.map { segment in
            if encodeAll {
                // Go url.PathEscape ≈ encode path segment (not full encodeURIComponent).
                var allowed = CharacterSet.urlPathAllowed
                allowed.remove(charactersIn: "/")
                return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
            }
            return segment
                .replacingOccurrences(of: "%", with: "%25")
                .replacingOccurrences(of: "?", with: "%3F")
                .replacingOccurrences(of: "#", with: "%23")
                .replacingOccurrences(of: " ", with: "%20")
        }
        return "/" + encoded.joined(separator: "/")
    }

    /// Official: POST /api/fs/mkdir  body `{ "path": "/new-dir" }`
    func mkdir(path: String) async throws {
        let normalized = OpenListPath.normalize(path)
        let body = try JSONSerialization.data(withJSONObject: ["path": normalized])
        try await postVoidEnvelope(path: "/api/fs/mkdir", body: body)
    }

    /// Official: POST /api/fs/remove  body `{ "names": [...], "dir": "..." }`
    func remove(names: [String], in directory: String) async throws {
        let dir = OpenListPath.normalize(directory)
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        let body = try JSONSerialization.data(withJSONObject: [
            "names": cleaned,
            "dir": dir
        ])
        try await postVoidEnvelope(path: "/api/fs/remove", body: body)
    }

    /// Official: PUT /api/fs/put with File-Path header (URL-encoded full path) + binary body.
    func upload(fileName: String, data: Data, toDirectory directory: String, asTask: Bool = true) async throws {
        let dir = OpenListPath.normalize(directory)
        let fullPath = OpenListPath.join(parent: dir, name: fileName)
        try await putData(fullPath: fullPath, data: data, contentType: "application/octet-stream", asTask: asTask)
    }

    /// Create or overwrite a text file via PUT /api/fs/put.
    func writeTextFile(path: String, content: String, asTask: Bool = false) async throws {
        let fullPath = OpenListPath.normalize(path)
        let data = Data(content.utf8)
        try await putData(fullPath: fullPath, data: data, contentType: "text/plain; charset=utf-8", asTask: asTask)
    }

    /// Official: POST /api/fs/rename  body `{ "path": "/old", "name": "new" }`
    func rename(path: String, name: String) async throws {
        let normalized = OpenListPath.normalize(path)
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !cleaned.contains("/") else {
            throw APIError.custom("Invalid name")
        }
        let body = try JSONSerialization.data(withJSONObject: [
            "path": normalized,
            "name": cleaned
        ])
        try await postVoidEnvelope(path: "/api/fs/rename", body: body)
    }

    /// Official: POST /api/fs/move  body `{ "src_dir", "dst_dir", "names" }`
    func move(names: [String], from srcDir: String, to dstDir: String) async throws {
        try await moveOrCopy(path: "/api/fs/move", names: names, from: srcDir, to: dstDir)
    }

    /// Official: POST /api/fs/copy  body `{ "src_dir", "dst_dir", "names" }`
    func copy(names: [String], from srcDir: String, to dstDir: String) async throws {
        try await moveOrCopy(path: "/api/fs/copy", names: names, from: srcDir, to: dstDir)
    }

    /// Official: POST /api/fs/archive/decompress  body `{ "src_dir", "name", "dst_dir" }`
    func decompress(name: String, from srcDir: String, to dstDir: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "src_dir": OpenListPath.normalize(srcDir),
            "name": name,
            "dst_dir": OpenListPath.normalize(dstDir)
        ])
        try await postVoidEnvelope(path: "/api/fs/archive/decompress", body: body)
    }

    /// Download remote file to a local file URL (Documents/Downloads). Returns local URL.
    @discardableResult
    func downloadToLocalFile(path: String, preferredName: String? = nil) async throws -> URL {
        let detail = try await detail(path: path)
        guard let remote = detail.contentURL ?? detail.playURL else {
            throw APIError.custom("No download URL")
        }
        let data = try await downloadFileBytes(from: remote)
        let name = preferredName
            ?? detail.item.name
            ?? OpenListPath.normalize(path).split(separator: "/").last.map(String.init)
            ?? "download"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var dest = dir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            let stamp = Int(Date().timeIntervalSince1970)
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            let suffix = ext.isEmpty ? "\(base)-\(stamp)" : "\(base)-\(stamp).\(ext)"
            dest = dir.appendingPathComponent(suffix)
        }
        try data.write(to: dest, options: .atomic)
        AppLogger.shared.info("downloaded \(name) -> \(dest.lastPathComponent) (\(data.count) bytes)", source: "OpenList")
        return dest
    }

    private func putData(fullPath: String, data: Data, contentType: String, asTask: Bool) async throws {
        let encodedPath = fullPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullPath
        guard !baseURL.isEmpty else { throw APIError.notConfigured }
        if token.isEmpty {
            if !username.isEmpty, !password.isEmpty {
                _ = try await loginAndStoreToken()
            } else {
                throw APIError.unauthorized
            }
        }
        var headers = authHeaders()
        headers["File-Path"] = encodedPath
        headers["Content-Type"] = contentType
        headers["Content-Length"] = "\(data.count)"
        if asTask {
            headers["As-Task"] = "true"
        }
        let responseData = try await engine.requestData(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: "/api/fs/put",
            method: "PUT",
            headers: headers,
            body: data
        )
        if let envelope = try? JSONDecoder().decode(OpenListEnvelope<OpenListEmptyData>.self, from: responseData) {
            guard envelope.code == 200 else {
                if envelope.code == 401 || envelope.code == 403 { throw APIError.unauthorized }
                let msg = envelope.message.trimmingCharacters(in: .whitespacesAndNewlines)
                throw APIError.custom(msg.isEmpty ? "Upload failed (\(envelope.code))" : msg)
            }
        }
    }

    private func moveOrCopy(path apiPath: String, names: [String], from srcDir: String, to dstDir: String) async throws {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        let body = try JSONSerialization.data(withJSONObject: [
            "src_dir": OpenListPath.normalize(srcDir),
            "dst_dir": OpenListPath.normalize(dstDir),
            "names": cleaned
        ])
        try await postVoidEnvelope(path: apiPath, body: body)
    }

    /// Ping still uses list for FS access check.
    func listRootForAuth() async throws {
        _ = try await list(path: "/")
    }

    func search(keyword: String, path: String? = nil) async throws -> [FileItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let scope = OpenListPath.normalize(path ?? "/")
        let body = try JSONSerialization.data(withJSONObject: [
            "parent": scope,
            "keywords": trimmed,
            "scope": 0,
            "page": 1,
            "per_page": 100,
            "password": ""
        ])
        let data: OpenListSearchData = try await getEnvelope(
            path: "/api/fs/search",
            method: "POST",
            body: body
        )
        return (data.content ?? []).map(FileItem.from(search:))
    }

    // MARK: - Private

    private func loginAndStoreToken(otpCode: String? = nil) async throws -> String {
        guard !baseURL.isEmpty else { throw APIError.notConfigured }
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password
        guard !user.isEmpty, !pass.isEmpty else { throw APIError.unauthorized }

        var payload: [String: Any] = [
            "username": user,
            "password": pass
        ]
        if let otpCode, !otpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["otp_code"] = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        // Login has no Authorization header
        let data = try await engine.requestData(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: "/api/auth/login",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: body
        )
        let envelope = try JSONDecoder().decode(OpenListEnvelope<OpenListLoginData>.self, from: data)
        guard envelope.code == 200, let login = envelope.data else {
            if envelope.code == 401 || envelope.code == 403 {
                throw APIError.unauthorized
            }
            let msg = envelope.message.trimmingCharacters(in: .whitespacesAndNewlines)
            throw APIError.custom(msg.isEmpty ? "OpenList login failed" : msg)
        }
        let jwt = login.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jwt.isEmpty else {
            throw APIError.custom("OpenList login returned empty token")
        }
        self.token = jwt
        onTokenRefresh?(jwt)
        // Refresh user base_path used by /d and /p links (OpenList web joins me().base_path).
        userBasePath = ""
        if let meData: OpenListMeData = try? await getEnvelope(path: "/api/me", method: "GET", body: nil) {
            if let raw = meData.base_path?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "/" {
                userBasePath = OpenListPath.normalize(raw)
            }
        }
        return jwt
    }

    private func authHeaders() -> [String: String] {
        // OpenList docs: put JWT in Authorization without "Bearer " prefix.
        var headers = ["Content-Type": "application/json"]
        if !token.isEmpty {
            headers["Authorization"] = token
        }
        return headers
    }

    private func getEnvelope<T: Decodable>(
        path: String,
        method: String,
        body: Data?
    ) async throws -> T {
        guard !baseURL.isEmpty else { throw APIError.notConfigured }
        if token.isEmpty {
            if !username.isEmpty, !password.isEmpty {
                _ = try await loginAndStoreToken()
            } else {
                throw APIError.unauthorized
            }
        }

        do {
            return try await performEnvelope(path: path, method: method, body: body)
        } catch APIError.unauthorized where !username.isEmpty && !password.isEmpty {
            _ = try await loginAndStoreToken()
            return try await performEnvelope(path: path, method: method, body: body)
        }
    }

    private func performEnvelope<T: Decodable>(
        path: String,
        method: String,
        body: Data?
    ) async throws -> T {
        let data = try await engine.requestData(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: path,
            method: method,
            headers: authHeaders(),
            body: body
        )
        let envelope = try JSONDecoder().decode(OpenListEnvelope<T>.self, from: data)
        guard envelope.code == 200, let payload = envelope.data else {
            if envelope.code == 401 || envelope.code == 403 {
                throw APIError.unauthorized
            }
            let msg = envelope.message.trimmingCharacters(in: .whitespacesAndNewlines)
            throw APIError.custom(msg.isEmpty ? "OpenList error \(envelope.code)" : msg)
        }
        return payload
    }

    private func postVoidEnvelope(path: String, body: Data) async throws {
        guard !baseURL.isEmpty else { throw APIError.notConfigured }
        if token.isEmpty {
            if !username.isEmpty, !password.isEmpty {
                _ = try await loginAndStoreToken()
            } else {
                throw APIError.unauthorized
            }
        }
        do {
            try await performVoid(path: path, method: "POST", body: body)
        } catch APIError.unauthorized where !username.isEmpty && !password.isEmpty {
            _ = try await loginAndStoreToken()
            try await performVoid(path: path, method: "POST", body: body)
        }
    }

    /// Void endpoints often return `data: null` — do not require a typed payload.
    private func performVoid(path: String, method: String, body: Data?) async throws {
        let data = try await engine.requestData(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: path,
            method: method,
            headers: authHeaders(),
            body: body
        )
        // Prefer loose decode: { code, message } — data may be null / missing / object.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = obj["code"] as? Int {
            guard code == 200 else {
                if code == 401 || code == 403 { throw APIError.unauthorized }
                let msg = (obj["message"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw APIError.custom(msg.isEmpty ? "OpenList error \(code)" : msg)
            }
            return
        }
        // Fallback typed decode
        if let envelope = try? JSONDecoder().decode(OpenListEnvelope<OpenListEmptyData>.self, from: data) {
            guard envelope.code == 200 else {
                if envelope.code == 401 || envelope.code == 403 { throw APIError.unauthorized }
                let msg = envelope.message.trimmingCharacters(in: .whitespacesAndNewlines)
                throw APIError.custom(msg.isEmpty ? "OpenList error \(envelope.code)" : msg)
            }
            return
        }
        throw APIError.custom("OpenList returned an unreadable response")
    }

    private static func cleanURL(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }
}

private struct OpenListEmptyData: Decodable {}
