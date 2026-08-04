import Foundation

actor ArcaneAPIClient {
    static let localEnvironmentId = ArcaneEnvironment.localId

    private let instanceId: UUID
    private var engine: BaseNetworkEngine
    private var storedAllowSelfSigned = true
    private var baseURL: String = ""
    private var fallbackURL: String = ""
    private var apiKey: String?
    private var jwtToken: String?
    private var username: String?
    private var storedPassword: String?
    private var isRefreshing = false
    private var onTokenRefreshed: (@Sendable (String) -> Void)?

    init(instanceId: UUID) {
        self.instanceId = instanceId
        self.engine = BaseNetworkEngine(serviceType: .arcane, instanceId: instanceId)
    }

    func configure(
        url: String,
        apiKey: String?,
        token: String?,
        fallbackUrl: String?,
        username: String?,
        password: String?,
        allowSelfSigned: Bool?
    ) {
        self.baseURL = Self.cleanURL(url)
        self.fallbackURL = Self.cleanURL(fallbackUrl ?? "")
        if let apiKey, !apiKey.isEmpty { self.apiKey = apiKey } else { self.apiKey = nil }
        if let token, !token.isEmpty { self.jwtToken = token }
        if let username, !username.isEmpty { self.username = username }
        if let password, !password.isEmpty { self.storedPassword = password }
        if let allowSelfSigned { storedAllowSelfSigned = allowSelfSigned }
        engine = BaseNetworkEngine(
            serviceType: .arcane,
            instanceId: self.instanceId,
            allowSelfSigned: self.storedAllowSelfSigned
        )
    }

    func setTokenRefreshCallback(_ callback: @escaping @Sendable (String) -> Void) {
        self.onTokenRefreshed = callback
    }

    /// Snapshot of auth headers for WebSocket handshakes (logs / terminal).
    /// Omits REST Content-Type so the upgrade request only carries credentials.
    func currentAuthHeaders() -> [String: String] { webSocketAuthHeaders() }

    func currentBaseURL() -> String { baseURL }

    private func authHeaders() -> [String: String] {
        // OpenAPI security scheme name is `X-API-Key` (HTTP headers are case-insensitive).
        // Arcane also accepts `X-Api-Key` (same header, case-insensitive).
        var headers = ["Content-Type": "application/json", "Accept": "application/json"]
        applyCredentialHeaders(to: &headers)
        return headers
    }

    /// Auth only — used for WebSocket upgrades (no Content-Type / Accept).
    private func webSocketAuthHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        applyCredentialHeaders(to: &headers)
        return headers
    }

    private func applyCredentialHeaders(to headers: inout [String: String]) {
        if let apiKey, !apiKey.isEmpty {
            headers["X-Api-Key"] = apiKey
        } else if let jwtToken, !jwtToken.isEmpty {
            headers["Authorization"] = "Bearer \(jwtToken)"
        }
    }

    private static func cleanURL(_ url: String) -> String {
        url.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    // MARK: - Auth / health

    func ping() async -> Bool {
        if baseURL.isEmpty { return false }
        if apiKey != nil || jwtToken != nil {
            if (try? await getEnvironments()) != nil { return true }
        }
        return await engine.pingWithAccessMode(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: "/api/health",
            extraHeaders: authHeaders()
        )
    }

    @discardableResult
    func login(username: String, password: String) async throws -> String {
        let wrapped: ArcaneAPIResponse<ArcaneLoginResponse> = try await engine.request(
            baseURL: baseURL,
            fallbackURL: fallbackURL,
            path: "/api/auth/login",
            method: "POST",
            headers: ["Content-Type": "application/json", "Accept": "application/json"],
            body: try JSONEncoder().encode(["username": username, "password": password])
        )
        let token = wrapped.data.token
        guard !token.isEmpty else {
            throw APIError.custom("Arcane login returned an empty token")
        }
        self.jwtToken = token
        self.username = username
        self.storedPassword = password
        onTokenRefreshed?(token)
        return token
    }

    // MARK: - Environments

    func getEnvironments() async throws -> [ArcaneEnvironment] {
        let response: ArcanePaginatedResponse<ArcaneEnvironment> = try await authenticatedRequest(
            path: "/api/environments?limit=100&start=0"
        )
        var envs = response.data
        if !envs.contains(where: { $0.id == Self.localEnvironmentId }) {
            envs.insert(
                ArcaneEnvironment(
                    id: Self.localEnvironmentId,
                    name: "Local Docker",
                    apiUrl: nil,
                    status: "online",
                    enabled: true,
                    isEdge: false,
                    lastSeen: nil
                ),
                at: 0
            )
        }
        return envs
    }

    // MARK: - Containers
    // OpenAPI: GET /environments/{id}/containers
    // Query: search, sort, order, start, limit, groupBy, includeInternal,
    //        updates (has_update|up_to_date|error|unknown), standalone (true|false)

    /// - Parameter updates: Official filter values from OpenAPI:
    ///   `has_update`, `up_to_date`, `error`, `unknown`.
    func getContainers(
        environmentId: String = localEnvironmentId,
        updates: String? = nil,
        standalone: String? = nil
    ) async throws -> [ArcaneContainer] {
        var all: [ArcaneContainer] = []
        var start = 0
        // OpenAPI default limit is 20; page until totalItems exhausted.
        let pageSize = 100

        while true {
            var path = "/api/environments/\(environmentId)/containers?limit=\(pageSize)&start=\(start)&order=asc"
            if let updates, !updates.isEmpty {
                let encoded = updates.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? updates
                path += "&updates=\(encoded)"
            }
            if let standalone, !standalone.isEmpty {
                path += "&standalone=\(standalone)"
            }

            // Soft item decoding: one bad container must not drop the whole page
            // (OpenAPI marks many nested fields required; live payloads can vary).
            let raw = try await authenticatedRequestData(path: path)
            let page = try Self.decodeContainerPage(from: raw)
            all.append(contentsOf: page.items)

            let total = page.totalItems ?? all.count
            start += page.items.count
            if page.items.isEmpty || start >= total || page.items.count < pageSize {
                break
            }
        }

        var seen = Set<String>()
        return all.filter { seen.insert($0.id).inserted }
    }

    private struct ContainerPage {
        let items: [ArcaneContainer]
        let totalItems: Int?
    }

    /// Decode `ContainerPaginatedResponse` with per-item tolerance.
    private static func decodeContainerPage(from data: Data) throws -> ContainerPage {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError(NSError(domain: "Arcane", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid container list JSON"
            ]))
        }
        let arr = root["data"] as? [[String: Any]] ?? []
        let pagination = root["pagination"] as? [String: Any]
        let totalItems = (pagination?["totalItems"] as? Int)
            ?? (pagination?["totalItems"] as? NSNumber)?.intValue

        let decoder = JSONDecoder()
        var items: [ArcaneContainer] = []
        items.reserveCapacity(arr.count)
        for dict in arr {
            guard let itemData = try? JSONSerialization.data(withJSONObject: dict) else { continue }
            if let c = try? decoder.decode(ArcaneContainer.self, from: itemData) {
                items.append(c)
            }
        }
        return ContainerPage(items: items, totalItems: totalItems)
    }

    func getContainerStatusCounts(environmentId: String = localEnvironmentId) async throws -> ArcaneStatusCounts {
        let response: ArcaneAPIResponse<ArcaneStatusCounts> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/containers/counts"
        )
        return response.data
    }

    func getContainerDetails(id: String, environmentId: String = localEnvironmentId) async throws -> ArcaneContainerDetails {
        let response: ArcaneAPIResponse<ArcaneContainerDetails> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/containers/\(id)"
        )
        return response.data
    }

    func containerAction(
        id: String,
        action: ArcaneContainerAction,
        environmentId: String = localEnvironmentId
    ) async throws {
        let _: ArcaneAPIResponse<ArcaneMessageBody> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/containers/\(id)/\(action.rawValue)",
            method: "POST"
        )
    }

    /// Pull latest image and recreate the container. Can take minutes; uses a long timeout.
    @discardableResult
    func updateContainer(id: String, environmentId: String = localEnvironmentId) async throws -> ArcaneUpdaterResult {
        let response: ArcaneAPIResponse<ArcaneUpdaterResult> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/containers/\(id)/update",
            method: "POST",
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        let result = response.data
        // HTTP 200 can still report per-resource failures in the body.
        if result.didFail, !result.didApplyUpdate {
            throw APIError.custom(result.userFacingSummary)
        }
        return result
    }

    @discardableResult
    func redeployContainer(id: String, environmentId: String = localEnvironmentId) async throws -> ArcaneContainerDetails {
        let response: ArcaneAPIResponse<ArcaneContainerDetails> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/containers/\(id)/redeploy",
            method: "POST",
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        return response.data
    }

    func deleteContainer(
        id: String,
        environmentId: String = localEnvironmentId,
        force: Bool = true,
        volumes: Bool = false
    ) async throws {
        let path = "/api/environments/\(environmentId)/containers/\(id)?force=\(force)&volumes=\(volumes)"
        let _: ArcaneAPIResponse<ArcaneMessageBody> = try await authenticatedRequest(path: path, method: "DELETE")
    }

    func setAutoUpdate(id: String, enabled: Bool, environmentId: String = localEnvironmentId) async throws {
        let _: ArcaneAPIResponse<ArcaneMessageBody> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/containers/\(id)/auto-update",
            method: "PUT",
            body: try JSONEncoder().encode(["enabled": enabled])
        )
    }

    // MARK: - Batch / system actions

    func startAllContainers(environmentId: String = localEnvironmentId) async throws -> ArcaneActionResult {
        let response: ArcaneAPIResponse<ArcaneActionResult> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/system/containers/start-all",
            method: "POST"
        )
        return response.data
    }

    func startStoppedContainers(environmentId: String = localEnvironmentId) async throws -> ArcaneActionResult {
        let response: ArcaneAPIResponse<ArcaneActionResult> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/system/containers/start-stopped",
            method: "POST"
        )
        return response.data
    }

    func stopAllContainers(environmentId: String = localEnvironmentId) async throws -> ArcaneActionResult {
        let response: ArcaneAPIResponse<ArcaneActionResult> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/system/containers/stop-all",
            method: "POST"
        )
        return response.data
    }

    /// Run Arcane updater (optional resourceIds = container/image ids).
    @discardableResult
    func runUpdater(
        environmentId: String = localEnvironmentId,
        resourceIds: [String]? = nil,
        forceUpdate: Bool = false,
        dryRun: Bool = false
    ) async throws -> ArcaneUpdaterResult {
        var body: [String: Any] = [
            "forceUpdate": forceUpdate,
            "dryRun": dryRun
        ]
        if let resourceIds, !resourceIds.isEmpty {
            body["resourceIds"] = resourceIds
            body["type"] = "container"
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: ArcaneAPIResponse<ArcaneUpdaterResult> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/updater/run",
            method: "POST",
            body: data,
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        let result = response.data
        if result.didFail, !result.didApplyUpdate {
            throw APIError.custom(result.userFacingSummary)
        }
        return result
    }

    func getImageUpdateSummary(environmentId: String = localEnvironmentId) async throws -> ArcaneImageUpdateSummary {
        let response: ArcaneAPIResponse<ArcaneImageUpdateSummary> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/image-updates/summary"
        )
        return response.data
    }

    // OpenAPI images list: updates filter documented as true/false (backend also accepts has_update).
    func getImagesWithUpdates(environmentId: String = localEnvironmentId) async throws -> [ArcaneImageSummary] {
        var all: [ArcaneImageSummary] = []
        var start = 0
        let pageSize = 100
        while true {
            // Documented query: updates=true|false
            let path = "/api/environments/\(environmentId)/images?updates=true&limit=\(pageSize)&start=\(start)"
            let response: ArcanePaginatedResponse<ArcaneImageSummary> = try await authenticatedRequest(path: path)
            all.append(contentsOf: response.data)
            let total = response.pagination?.totalItems ?? all.count
            start += response.data.count
            if response.data.isEmpty || start >= total || response.data.count < pageSize { break }
        }
        return all
    }

    // OpenAPI: GET /environments/{id}/images/counts
    func getImageUsageCounts(environmentId: String = localEnvironmentId) async throws -> ArcaneImageUsageCounts {
        let response: ArcaneAPIResponse<ArcaneImageUsageCounts> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/images/counts"
        )
        return response.data
    }

    /// OpenAPI: POST /environments/{id}/images/prune
    /// - dangling query/body: only remove dangling images when true
    @discardableResult
    func pruneImages(
        environmentId: String = localEnvironmentId,
        danglingOnly: Bool = true
    ) async throws -> ArcaneImagePruneReport {
        let body = try JSONSerialization.data(withJSONObject: [
            "dangling": danglingOnly
        ])
        let response: ArcaneAPIResponse<ArcaneImagePruneReport> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/images/prune?dangling=\(danglingOnly)",
            method: "POST",
            body: body,
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        return response.data
    }

    /// OpenAPI: POST /environments/{id}/volumes/prune
    @discardableResult
    func pruneVolumes(environmentId: String = localEnvironmentId) async throws -> ArcaneVolumePruneReport {
        let response: ArcaneAPIResponse<ArcaneVolumePruneReport> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/volumes/prune",
            method: "POST",
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        return response.data
    }

    /// OpenAPI: POST /environments/{id}/networks/prune
    @discardableResult
    func pruneNetworks(environmentId: String = localEnvironmentId) async throws -> ArcaneNetworkPruneReport {
        let response: ArcaneAPIResponse<ArcaneNetworkPruneReport> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/networks/prune",
            method: "POST",
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        return response.data
    }

    /// OpenAPI: POST /environments/{id}/system/prune
    /// Body SystemPruneAllRequest — each resource uses `mode` (e.g. unused / dangling).
    @discardableResult
    func pruneSystem(
        environmentId: String = localEnvironmentId,
        images: Bool = true,
        volumes: Bool = false,
        networks: Bool = true,
        containers: Bool = false,
        buildCache: Bool = false,
        imageMode: String = "unused"
    ) async throws -> ArcaneSystemPruneResult {
        var body: [String: Any] = [:]
        if images { body["images"] = ["mode": imageMode] }
        if volumes { body["volumes"] = ["mode": "unused"] }
        if networks { body["networks"] = ["mode": "unused"] }
        if containers { body["containers"] = ["mode": "unused"] }
        if buildCache { body["buildCache"] = ["mode": "unused"] }
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: ArcaneAPIResponse<ArcaneSystemPruneResult> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/system/prune",
            method: "POST",
            body: data,
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        return response.data
    }

    /// OpenAPI: POST /environments/{id}/image-updates/check-all
    @discardableResult
    func checkAllImageUpdates(environmentId: String = localEnvironmentId) async throws -> [String: ArcaneImageUpdateInfo] {
        let data = try JSONSerialization.data(withJSONObject: [:] as [String: Any])
        let raw = try await authenticatedRequestData(
            path: "/api/environments/\(environmentId)/image-updates/check-all",
            method: "POST",
            body: data,
            timeout: BaseNetworkEngine.longRunningTimeout
        )
        guard let root = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return [:] }
        // Batch response is map of imageRef → update result
        let payload = (root["data"] as? [String: Any]) ?? root
        var out: [String: ArcaneImageUpdateInfo] = [:]
        let decoder = JSONDecoder()
        for (key, value) in payload {
            guard let dict = value as? [String: Any],
                  let entryData = try? JSONSerialization.data(withJSONObject: dict),
                  let info = try? decoder.decode(ArcaneImageUpdateInfo.self, from: entryData) else { continue }
            out[key] = info
        }
        return out
    }

    /// OpenAPI: GET /environments/{id}/image-updates/by-refs?imageRefs=a,b,c
    /// Response: BaseApiResponseMapStringUpdateInfo
    func getUpdateInfoByImageRefs(
        environmentId: String = localEnvironmentId,
        imageRefs: [String]
    ) async throws -> [String: ArcaneImageUpdateInfo] {
        let unique = Array(Set(imageRefs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        var merged: [String: ArcaneImageUpdateInfo] = [:]
        let chunkSize = 40
        var index = 0
        while index < unique.count {
            let end = min(index + chunkSize, unique.count)
            let chunk = Array(unique[index..<end])
            index = end
            let joined = chunk
                .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
                .joined(separator: ",")
            let path = "/api/environments/\(environmentId)/image-updates/by-refs?imageRefs=\(joined)"
            let raw = try await authenticatedRequestData(path: path)
            guard let root = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
            guard let dataObj = root["data"] as? [String: Any] else { continue }
            let decoder = JSONDecoder()
            for (key, value) in dataObj {
                guard let dict = value as? [String: Any] else { continue }
                guard let entryData = try? JSONSerialization.data(withJSONObject: dict) else { continue }
                if let info = try? decoder.decode(ArcaneImageUpdateInfo.self, from: entryData) {
                    merged[key] = info
                }
            }
        }
        return merged
    }

    /// Containers with available updates — only uses documented OpenAPI endpoints:
    /// 1) GET containers?updates=has_update
    /// 2) GET image-updates/by-refs + match container.image
    /// 3) GET images?updates=has_update + match imageId / usedBy
    func getContainersNeedingUpdate(environmentId: String = localEnvironmentId) async throws -> [ArcaneContainer] {
        // Path 1 — documented container filter (same as Arcane Updates UI without standalone).
        let filtered = try await getContainers(environmentId: environmentId, updates: "has_update")
        if !filtered.isEmpty { return filtered }

        let all = try await getContainers(environmentId: environmentId)
        if all.isEmpty { return [] }

        // Also accept updateInfo already present on the unfiltered list.
        let localHits = all.filter(\.hasUpdate)
        if !localHits.isEmpty { return localHits }

        // Path 2 — documented by-refs map keyed by image reference string.
        let refs = all.map(\.image).filter { !$0.isEmpty }
        if let byRef = try? await getUpdateInfoByImageRefs(environmentId: environmentId, imageRefs: refs),
           !byRef.isEmpty {
            let hits = all.filter { c in
                Self.lookupUpdateInfo(byRef, forImage: c.image)?.available == true
            }
            if !hits.isEmpty { return hits }
        }

        // Path 3 — documented images list filter + UsedBy / imageId join.
        if let updateImages = try? await getImagesWithUpdates(environmentId: environmentId),
           !updateImages.isEmpty {
            let imageIds = Set(updateImages.map(\.id))
            let tags = Set(updateImages.flatMap { ($0.repoTags ?? []) + [$0.primaryTag] }.map { $0.lowercased() })
            var usedIds = Set<String>()
            var usedNames = Set<String>()
            for img in updateImages {
                usedIds.formUnion(img.usedContainerIds)
                usedNames.formUnion(img.usedContainerNames.map { $0.lowercased() })
            }
            let matched = all.filter { c in
                if usedIds.contains(where: { c.id == $0 || c.id.hasPrefix($0) || $0.hasPrefix(c.id) }) {
                    return true
                }
                if usedNames.contains(c.displayName.lowercased()) { return true }
                if let imageId = c.imageId,
                   imageIds.contains(where: { $0 == imageId || $0.hasPrefix(imageId) || imageId.hasPrefix($0) }) {
                    return true
                }
                let imageName = c.image.lowercased()
                return tags.contains(imageName)
                    || tags.contains(where: { imageName == $0 || imageName.hasPrefix($0 + "@") })
            }
            if !matched.isEmpty { return matched }
        }

        return []
    }

    private static func lookupUpdateInfo(
        _ map: [String: ArcaneImageUpdateInfo],
        forImage image: String
    ) -> ArcaneImageUpdateInfo? {
        if let exact = map[image] { return exact }
        let lower = image.lowercased()
        if let hit = map.first(where: { $0.key.lowercased() == lower })?.value { return hit }
        func normalize(_ s: String) -> String {
            s.lowercased()
                .replacingOccurrences(of: "docker.io/", with: "")
                .replacingOccurrences(of: "library/", with: "")
        }
        let bare = normalize(image)
        return map.first(where: { normalize($0.key) == bare })?.value
    }

    // MARK: - Activities (update / pull progress)

    func listActivities(
        environmentId: String = localEnvironmentId,
        status: String? = nil,
        type: String? = nil,
        limit: Int = 30
    ) async throws -> [ArcaneActivity] {
        var path = "/api/environments/\(environmentId)/activities?limit=\(limit)&start=0&order=desc"
        if let status, !status.isEmpty {
            path += "&status=\(status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? status)"
        }
        if let type, !type.isEmpty {
            path += "&type=\(type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? type)"
        }
        let response: ArcanePaginatedResponse<ArcaneActivity> = try await authenticatedRequest(path: path)
        return response.data
    }

    func getActivity(
        id: String,
        environmentId: String = localEnvironmentId,
        limit: Int = 500
    ) async throws -> ArcaneActivityDetail {
        let response: ArcaneAPIResponse<ArcaneActivityDetail> = try await authenticatedRequest(
            path: "/api/environments/\(environmentId)/activities/\(id)?limit=\(limit)"
        )
        return response.data
    }

    /// Resolve a container by display name after recreate (update changes Docker ID).
    func findContainerId(
        named displayName: String,
        environmentId: String = localEnvironmentId,
        preferredPrefix: String? = nil
    ) async throws -> String? {
        let name = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^/", with: "", options: .regularExpression)
            .lowercased()
        guard !name.isEmpty else { return nil }
        let containers = try await getContainers(environmentId: environmentId)
        if let preferredPrefix, !preferredPrefix.isEmpty,
           let exact = containers.first(where: { $0.id == preferredPrefix || $0.id.hasPrefix(preferredPrefix) }) {
            return exact.id
        }
        return containers.first(where: { $0.displayName.lowercased() == name })?.id
            ?? containers.first(where: { $0.displayName.lowercased().contains(name) })?.id
    }

    func getDockerInfo(environmentId: String = localEnvironmentId) async throws -> ArcaneDockerInfo {
        // Docker info is returned as a raw Docker API object (not always {success,data}).
        let data = try await authenticatedRequestData(
            path: "/api/environments/\(environmentId)/system/docker/info"
        )
        if let wrapped = try? JSONDecoder().decode(ArcaneAPIResponse<ArcaneDockerInfo>.self, from: data) {
            return wrapped.data
        }
        return try JSONDecoder().decode(ArcaneDockerInfo.self, from: data)
    }

    // MARK: - Logs via WebSocket
    //
    // Arcane 2.x has NO REST endpoint for container logs.
    // - Official OpenAPI `/diagnostics/logs` is backend process logs only.
    // - Container logs are WebSocket-only (same as Arcane web log-viewer):
    //   GET /api/environments/{envId}/ws/containers/{containerId}/logs
    //   query: follow, tail, timestamps, format=json|text, batched

    func getContainerLogs(
        id: String,
        environmentId: String = localEnvironmentId,
        tail: Int = 200
    ) async throws -> String {
        // Snapshot: unbatched JSON so each log line arrives as its own frame (no 400ms batch window).
        let path = Self.containerLogsWSPath(
            environmentId: environmentId,
            containerId: id,
            follow: false,
            tail: tail,
            timestamps: true,
            format: "json",
            batched: false
        )
        let frames = try await openWebSocketTextStream(
            path: path,
            maxMessages: max(tail + 80, 120),
            timeoutSeconds: 15
        )
        var lines: [String] = []
        for frame in frames {
            lines.append(contentsOf: ArcaneTextSanitizer.parseLogWSPayload(frame))
        }
        // Fallback to plain text stream if JSON produced nothing.
        if lines.isEmpty {
            let textPath = Self.containerLogsWSPath(
                environmentId: environmentId,
                containerId: id,
                follow: false,
                tail: tail,
                timestamps: false,
                format: "text",
                batched: false
            )
            let textFrames = try await openWebSocketTextStream(
                path: textPath,
                maxMessages: max(tail + 50, 100),
                timeoutSeconds: 12
            )
            lines = textFrames.flatMap { frame -> [String] in
                let cleaned = ArcaneTextSanitizer.stripANSI(frame)
                if cleaned.contains("\n") {
                    return cleaned.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                }
                return cleaned.isEmpty ? [] : [cleaned]
            }
        }
        let joined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if joined.isEmpty {
            throw APIError.custom("No log output received (container may have empty logs)")
        }
        return joined
    }

    /// WebSocket URL for interactive terminal (shell).
    func terminalWebSocketURL(
        containerId: String,
        environmentId: String = localEnvironmentId,
        shell: String = "/bin/sh"
    ) throws -> URL {
        let encodedShell = shell.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shell
        let encodedId = containerId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerId
        let path = "/api/environments/\(environmentId)/ws/containers/\(encodedId)/terminal?shell=\(encodedShell)"
        return try makeWebSocketURL(path: path)
    }

    func logsWebSocketURL(
        containerId: String,
        environmentId: String = localEnvironmentId,
        tail: Int = 200,
        follow: Bool = true
    ) throws -> URL {
        // Same query shape as Arcane frontend log-viewer.svelte
        let path = Self.containerLogsWSPath(
            environmentId: environmentId,
            containerId: containerId,
            follow: follow,
            tail: tail,
            timestamps: true,
            format: "json",
            batched: true
        )
        return try makeWebSocketURL(path: path)
    }

    /// Builds the official Arcane container-log WebSocket path (not OpenAPI REST).
    private static func containerLogsWSPath(
        environmentId: String,
        containerId: String,
        follow: Bool,
        tail: Int,
        timestamps: Bool,
        format: String,
        batched: Bool
    ) -> String {
        let encodedId = containerId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerId
        return "/api/environments/\(environmentId)/ws/containers/\(encodedId)/logs"
            + "?follow=\(follow)"
            + "&tail=\(tail)"
            + "&timestamps=\(timestamps)"
            + "&format=\(format)"
            + "&batched=\(batched)"
    }

    // MARK: - Private request helpers

    private func authenticatedRequest<T: Decodable & Sendable>(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        do {
            return try await engine.request(
                baseURL: baseURL,
                fallbackURL: fallbackURL,
                path: path,
                method: method,
                headers: authHeaders(),
                body: body,
                timeout: timeout
            )
        } catch {
            if isAuthError(error), !isRefreshing, apiKey == nil,
               let storedUsername = username, let storedPassword = storedPassword {
                isRefreshing = true
                defer { isRefreshing = false }
                try await login(username: storedUsername, password: storedPassword)
                return try await engine.request(
                    baseURL: baseURL,
                    fallbackURL: fallbackURL,
                    path: path,
                    method: method,
                    headers: authHeaders(),
                    body: body,
                    timeout: timeout
                )
            }
            throw error
        }
    }

    private func authenticatedRequestData(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> Data {
        do {
            return try await engine.requestData(
                baseURL: baseURL,
                fallbackURL: fallbackURL,
                path: path,
                method: method,
                headers: authHeaders(),
                body: body,
                timeout: timeout
            )
        } catch {
            if isAuthError(error), !isRefreshing, apiKey == nil,
               let storedUsername = username, let storedPassword = storedPassword {
                isRefreshing = true
                defer { isRefreshing = false }
                try await login(username: storedUsername, password: storedPassword)
                return try await engine.requestData(
                    baseURL: baseURL,
                    fallbackURL: fallbackURL,
                    path: path,
                    method: method,
                    headers: authHeaders(),
                    body: body,
                    timeout: timeout
                )
            }
            throw error
        }
    }

    private func isAuthError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .httpError(let code, _): return code == 401 || code == 403
        case .unauthorized: return true
        case .bothURLsFailed(let primary, let fallback): return isAuthError(primary) || isAuthError(fallback)
        default: return false
        }
    }

    // MARK: - WebSocket

    private func makeWebSocketURL(path: String) throws -> URL {
        var root = baseURL
        if root.hasPrefix("https://") {
            root = "wss://" + root.dropFirst("https://".count)
        } else if root.hasPrefix("http://") {
            root = "ws://" + root.dropFirst("http://".count)
        } else if !root.hasPrefix("ws") {
            root = "ws://" + root
        }
        guard let url = URL(string: root + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func openWebSocketTextStream(
        path: String,
        maxMessages: Int,
        timeoutSeconds: TimeInterval
    ) async throws -> [String] {
        let url = try makeWebSocketURL(path: path)
        let headers = webSocketAuthHeaders()
        let allowSelfSigned = storedAllowSelfSigned
        // Run outside actor isolation so a stuck WS receive cannot wedge the client actor.
        return try await Self.collectWebSocketFrames(
            url: url,
            headers: headers,
            allowSelfSigned: allowSelfSigned,
            maxMessages: maxMessages,
            timeoutSeconds: timeoutSeconds
        )
    }

    /// Collect WS text frames with a **non-blocking** timeout.
    ///
    /// `URLSessionWebSocketTask.receive()` often ignores Task cancellation. Racing it with
    /// `Task.sleep` inside a throwing task group will hang forever on group exit while waiting
    /// for the cancelled receive to finish. Use a one-shot continuation instead.
    private nonisolated static func collectWebSocketFrames(
        url: URL,
        headers: [String: String],
        allowSelfSigned: Bool,
        maxMessages: Int,
        timeoutSeconds: TimeInterval
    ) async throws -> [String] {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutSeconds
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let session = URLSession(
            configuration: .default,
            delegate: allowSelfSigned ? InsecureTrustDelegate() : nil,
            delegateQueue: nil
        )
        let task = session.webSocketTask(with: request)
        task.resume()
        defer {
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
        }

        var frames: [String] = []
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var idleRounds = 0
        let maxIdleAfterData = 3
        var lastError: Error?

        while frames.count < maxMessages, Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { break }
            let waitSlice = frames.isEmpty ? min(remaining, 4.0) : min(remaining, 0.6)
            do {
                let message = try await receiveWebSocketMessage(task, timeout: waitSlice)
                idleRounds = 0
                lastError = nil
                switch message {
                case .string(let text):
                    frames.append(contentsOf: splitLogWSFrame(text))
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        frames.append(contentsOf: splitLogWSFrame(text))
                    }
                @unknown default:
                    break
                }
            } catch {
                lastError = error
                if !frames.isEmpty {
                    idleRounds += 1
                    if idleRounds >= maxIdleAfterData { break }
                    continue
                }
                if isFatalWebSocketError(error) {
                    throw APIError.custom("Arcane log stream failed: \(error.localizedDescription)")
                }
                if Date() >= deadline { break }
            }
        }

        if frames.isEmpty, let lastError, isFatalWebSocketError(lastError) {
            throw APIError.custom("Arcane log stream failed: \(lastError.localizedDescription)")
        }
        return frames
    }

    /// Race `receive()` against a timer without awaiting a cancelled receive (prevents hangs).
    private nonisolated static func receiveWebSocketMessage(
        _ task: URLSessionWebSocketTask,
        timeout: TimeInterval
    ) async throws -> URLSessionWebSocketTask.Message {
        final class OnceResume: @unchecked Sendable {
            private let lock = NSLock()
            private var settled = false
            private let continuation: CheckedContinuation<URLSessionWebSocketTask.Message, Error>
            init(_ continuation: CheckedContinuation<URLSessionWebSocketTask.Message, Error>) {
                self.continuation = continuation
            }
            func resume(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !settled else { return }
                settled = true
                continuation.resume(with: result)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let once = OnceResume(continuation)
            // Unstructured tasks: timeout must not wait for a non-cancellable receive().
            Task {
                do {
                    let message = try await task.receive()
                    once.resume(.success(message))
                } catch {
                    once.resume(.failure(error))
                }
            }
            Task {
                let ns = UInt64(max(timeout, 0.05) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                once.resume(.failure(URLError(.timedOut)))
            }
        }
    }

    /// Keep JSON frames whole; split plain multi-line text only.
    private static func splitLogWSFrame(_ text: String) -> [String] {
        let trimmedStart = text.trimmingCharacters(in: .whitespaces)
        if trimmedStart.hasPrefix("{") || trimmedStart.hasPrefix("[") {
            return text.isEmpty ? [] : [text]
        }
        if text.contains("\n") {
            return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }
        return text.isEmpty ? [] : [text]
    }

    private static func isFatalWebSocketError(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case URLError.timedOut.rawValue,
                 URLError.cancelled.rawValue,
                 URLError.networkConnectionLost.rawValue:
                return false
            default:
                return true
            }
        }
        // URLSession WebSocket often surfaces close/HTTP failures as NSPOSIXErrorDomain / generic.
        let desc = error.localizedDescription.lowercased()
        if desc.contains("timed out") || desc.contains("canceled") || desc.contains("cancelled") {
            return false
        }
        if desc.contains("unauthorized") || desc.contains("forbidden")
            || desc.contains("401") || desc.contains("403")
            || desc.contains("not found") || desc.contains("404") {
            return true
        }
        return false
    }
}
