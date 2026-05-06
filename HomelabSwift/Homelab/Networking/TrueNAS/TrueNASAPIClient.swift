import Foundation

actor TrueNASAPIClient {
    private enum ProtocolMode {
        case jsonRPC(endpoint: String)
        case ddp
    }

    private let instanceId: UUID
    private var baseURL: String = ""
    private var fallbackURL: String = ""
    private var apiKey: String = ""
    private var storedAllowSelfSigned = true

    init(instanceId: UUID) {
        self.instanceId = instanceId
    }

    func configure(
        url: String,
        apiKey: String,
        fallbackUrl: String? = nil,
        allowSelfSigned: Bool? = nil
    ) {
        self.baseURL = Self.cleanURL(url)
        self.fallbackURL = Self.cleanURL(fallbackUrl ?? "")
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if let allowSelfSigned {
            storedAllowSelfSigned = allowSelfSigned
        }
    }

    func authenticate(url: String, apiKey: String, fallbackUrl: String? = nil) async throws {
        let cleanURL = Self.cleanURL(url)
        let cleanFallback = Self.cleanURL(fallbackUrl ?? "")
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanURL.isEmpty, !cleanKey.isEmpty else { throw APIError.notConfigured }

        do {
            _ = try await requestJSONObject(
                baseURL: cleanURL,
                fallbackURL: cleanFallback,
                apiKey: cleanKey,
                method: "system.info",
                params: []
            )
        } catch {
            throw APIError.unauthorized
        }
    }

    func ping() async -> Bool {
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return false }
        return (try? await requestJSONObject(method: "system.info", params: [])) != nil
    }

    func getDashboardSnapshot() async throws -> TrueNASDashboardSnapshot {
        let systemObject = try await requestJSONObject(method: "system.info", params: [])
        let poolParams: [Any] = [[], ["extra": ["is_upgraded": false]]]
        let diskParams: [Any] = [[], ["extra": ["pools": true]]]
        let poolObject = (try? await requestJSONObject(method: "pool.query", params: poolParams)) ?? []
        let diskObject = (try? await requestJSONObject(method: "disk.query", params: diskParams)) ?? []
        let alertObject = (try? await requestJSONObject(method: "alert.list", params: [])) ?? []
        let serviceObject = (try? await requestJSONObject(method: "service.query", params: [])) ?? []
        let smbShareObject = (try? await requestJSONObject(method: "sharing.smb.query", params: [])) ?? []
        let nfsShareObject = (try? await requestJSONObject(method: "sharing.nfs.query", params: [])) ?? []
        let iscsiShareObject = await requestFirstJSONObject(
            methods: ["iscsi.target.query", "sharing.iscsi.target.query"],
            params: []
        )
        let appObject = (try? await requestJSONObject(method: "app.query", params: [])) ?? []
        let vmObject = (try? await requestJSONObject(method: "vm.query", params: [])) ?? []

        let system = Self.parseSystemInfo(systemObject)
        let pools = Self.parsePools(poolObject)
        let disks = Self.parseDisks(diskObject)
        let alerts = Self.parseAlerts(alertObject)
        let services = Self.parseServices(serviceObject)
        let shares = Self.parseShareSummary(smbObject: smbShareObject, nfsObject: nfsShareObject, iscsiObject: iscsiShareObject)
        let workloads = Self.parseWorkloadSummary(appObject: appObject, vmObject: vmObject)

        return TrueNASDashboardSnapshot(
            system: system,
            pools: pools,
            disks: disks,
            alerts: alerts,
            services: services,
            shareSummary: shares,
            workloadSummary: workloads
        )
    }

    // MARK: - Request routing

    private func requestJSONObject(method: String, params: [Any]) async throws -> Any {
        try await requestJSONObject(baseURL: baseURL, fallbackURL: fallbackURL, apiKey: apiKey, method: method, params: params)
    }

    private func requestFirstJSONObject(methods: [String], params: [Any]) async -> Any {
        for method in methods {
            if let object = try? await requestJSONObject(method: method, params: params) {
                return object
            }
        }
        return []
    }

    private func requestJSONObject(
        baseURL: String,
        fallbackURL: String,
        apiKey: String,
        method: String,
        params: [Any]
    ) async throws -> Any {
        do {
            return try await requestJSONObject(baseURL: baseURL, apiKey: apiKey, method: method, params: params)
        } catch let primaryError {
            guard !fallbackURL.isEmpty else { throw primaryError }
            do {
                return try await requestJSONObject(baseURL: fallbackURL, apiKey: apiKey, method: method, params: params)
            } catch let fallbackError {
                throw APIError.bothURLsFailed(primaryError: primaryError, fallbackError: fallbackError)
            }
        }
    }

    private func requestJSONObject(baseURL: String, apiKey: String, method: String, params: [Any]) async throws -> Any {
        var lastError: Error?
        for mode in protocolModes {
            do {
                switch mode {
                case .jsonRPC(let endpoint):
                    return try await requestJSONRPC(baseURL: baseURL, endpoint: endpoint, apiKey: apiKey, method: method, params: params)
                case .ddp:
                    return try await requestDDP(baseURL: baseURL, apiKey: apiKey, method: method, params: params)
                }
            } catch {
                lastError = error
            }
        }
        throw lastError ?? APIError.networkError(URLError(.cannotConnectToHost))
    }

    private var protocolModes: [ProtocolMode] {
        [
            .jsonRPC(endpoint: "/api/current"),
            .jsonRPC(endpoint: "/api/v25.04"),
            .jsonRPC(endpoint: "/websocket"),
            .ddp
        ]
    }

    static func usesSecureAPITransport(_ rawURL: String) -> Bool {
        guard let components = URLComponents(string: cleanURL(rawURL)),
              let scheme = components.scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || scheme == "wss"
    }

    // MARK: - JSON-RPC 2.0

    private func requestJSONRPC(
        baseURL: String,
        endpoint: String,
        apiKey: String,
        method: String,
        params: [Any]
    ) async throws -> Any {
        let task = try makeWebSocketTask(baseURL: baseURL, endpoint: endpoint)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        let authResult = try await jsonRPCCall(task: task, id: "auth-\(UUID().uuidString)", method: "auth.login_with_api_key", params: [apiKey])
        if let accepted = authResult as? Bool, accepted == false {
            throw APIError.unauthorized
        }
        return try await jsonRPCCall(task: task, id: "call-\(UUID().uuidString)", method: method, params: params)
    }

    private func jsonRPCCall(task: URLSessionWebSocketTask, id: String, method: String, params: [Any]) async throws -> Any {
        try await sendJSON(task: task, object: [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ])

        while true {
            let object = try await receiveJSONObject(task: task)
            guard let dict = object as? [String: Any],
                  Self.stringValue(dict["id"]) == id else {
                continue
            }
            if let error = dict["error"] {
                throw APIError.custom(Self.errorMessage(from: error))
            }
            if let result = dict["result"] {
                return result
            }
            return [:]
        }
    }

    // MARK: - DDP fallback for CORE / older SCALE

    private func requestDDP(baseURL: String, apiKey: String, method: String, params: [Any]) async throws -> Any {
        let task = try makeWebSocketTask(baseURL: baseURL, endpoint: "/websocket")
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        try await sendJSON(task: task, object: [
            "msg": "connect",
            "version": "1",
            "support": ["1"]
        ])
        try await waitForDDPConnected(task: task)

        let authResult = try await ddpMethodCall(task: task, method: "auth.login_with_api_key", params: [apiKey])
        if let accepted = authResult as? Bool, accepted == false {
            throw APIError.unauthorized
        }
        return try await ddpMethodCall(task: task, method: method, params: params)
    }

    private func waitForDDPConnected(task: URLSessionWebSocketTask) async throws {
        while true {
            let object = try await receiveJSONObject(task: task)
            guard let dict = object as? [String: Any],
                  let msg = dict["msg"] as? String else {
                continue
            }
            if msg == "connected" {
                return
            }
            if msg == "failed" {
                throw APIError.custom(Self.errorMessage(from: dict["reason"] ?? dict))
            }
        }
    }

    private func ddpMethodCall(task: URLSessionWebSocketTask, method: String, params: [Any]) async throws -> Any {
        let id = "ddp-\(UUID().uuidString)"
        try await sendJSON(task: task, object: [
            "id": id,
            "msg": "method",
            "method": method,
            "params": params
        ])

        while true {
            let object = try await receiveJSONObject(task: task)
            guard let dict = object as? [String: Any],
                  dict["msg"] as? String == "result",
                  Self.stringValue(dict["id"]) == id else {
                continue
            }
            if let error = dict["error"] {
                throw APIError.custom(Self.errorMessage(from: error))
            }
            if let result = dict["result"] {
                return result
            }
            return [:]
        }
    }

    // MARK: - WebSocket helpers

    private func makeWebSocketTask(baseURL: String, endpoint: String) throws -> URLSessionWebSocketTask {
        let cleanURL = Self.cleanURL(baseURL)
        guard var components = URLComponents(string: cleanURL) else { throw APIError.invalidURL }
        guard Self.usesSecureAPITransport(cleanURL) else {
            throw APIError.custom(Translations.current().truenasSecureTransportRequired)
        }
        switch components.scheme?.lowercased() {
        case "https":
            components.scheme = "wss"
        case "http":
            components.scheme = "ws"
        case "ws", "wss":
            break
        default:
            components.scheme = "wss"
        }
        components.path = endpoint
        components.query = nil
        guard let url = components.url else { throw APIError.invalidURL }
        let session = BaseNetworkEngine.authSession(allowSelfSigned: storedAllowSelfSigned, timeout: 10)
        return session.webSocketTask(with: url)
    }

    private func sendJSON(task: URLSessionWebSocketTask, object: Any) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw APIError.decodingError(URLError(.cannotDecodeRawData))
        }
        try await task.send(.string(text))
    }

    private func receiveJSONObject(task: URLSessionWebSocketTask) async throws -> Any {
        let message = try await task.receive()
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let rawData):
            data = rawData
        @unknown default:
            throw APIError.decodingError(URLError(.cannotDecodeContentData))
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: - Parsing

    private static func parseSystemInfo(_ object: Any) -> TrueNASSystemInfo {
        let dict = object as? [String: Any] ?? [:]
        return TrueNASSystemInfo(
            version: stringValue(dict["version"]) ?? stringValue(dict["version_short"]) ?? "TrueNAS",
            hostname: stringValue(dict["hostname"]) ?? stringValue(dict["system_product"]),
            uptime: stringValue(dict["uptime"]) ?? stringValue(dict["uptime_seconds"]).map(formatUptimeSeconds),
            systemProduct: stringValue(dict["system_product"]) ?? stringValue(dict["product_type"])
        )
    }

    private static func parsePools(_ object: Any) -> [TrueNASPool] {
        guard let rows = object as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            let name = stringValue(row["name"]) ?? stringValue(row["id"]) ?? "Pool"
            let status = stringValue(row["status"]) ?? stringValue(row["healthy"]) ?? "UNKNOWN"
            let statusUpper = status.uppercased()
            let healthy = boolValue(row["healthy"]) ?? (statusUpper.contains("ONLINE") || statusUpper.contains("HEALTHY"))
            let topology = row["topology"] as? [String: Any]
            let size = doubleValue(row["size"]) ?? doubleValue(row["total"]) ?? doubleValue(topology?["size"]) ?? 0
            let allocated = doubleValue(row["allocated"]) ?? doubleValue(row["used"]) ?? doubleValue(topology?["allocated"]) ?? 0
            let free = doubleValue(row["free"]) ?? doubleValue(row["available"]) ?? max(size - allocated, 0)
            return TrueNASPool(
                id: stringValue(row["id"]) ?? name,
                name: name,
                status: status,
                healthy: healthy,
                sizeBytes: size,
                usedBytes: allocated,
                availableBytes: free
            )
        }
    }

    private static func parseDisks(_ object: Any) -> [TrueNASDisk] {
        guard let rows = object as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            let name = stringValue(row["name"]) ?? stringValue(row["devname"]) ?? stringValue(row["identifier"]) ?? "Disk"
            return TrueNASDisk(
                id: stringValue(row["identifier"]) ?? stringValue(row["serial"]) ?? name,
                name: name,
                model: stringValue(row["model"]),
                serial: stringValue(row["serial"]),
                sizeBytes: doubleValue(row["size"]) ?? 0,
                pool: stringValue(row["pool"])
            )
        }
    }

    private static func parseAlerts(_ object: Any) -> [TrueNASAlert] {
        guard let rows = object as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            let message = stringValue(row["formatted"]) ?? stringValue(row["text"]) ?? stringValue(row["message"])
            guard let message, !message.isEmpty else { return nil }
            return TrueNASAlert(
                id: stringValue(row["uuid"]) ?? stringValue(row["id"]) ?? "\(message.hashValue)",
                level: stringValue(row["level"]) ?? stringValue(row["klass"]) ?? "INFO",
                message: message,
                createdAt: stringValue(row["datetime"]) ?? stringValue(row["created_at"])
            )
        }
    }

    private static func parseServices(_ object: Any) -> [TrueNASServiceStatus] {
        guard let rows = object as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            let name = stringValue(row["service"]) ?? stringValue(row["name"]) ?? stringValue(row["id"])
            guard let name, !name.isEmpty else { return nil }
            let state = stringValue(row["state"]) ?? stringValue(row["pids"]) ?? "UNKNOWN"
            let normalizedState = state.uppercased()
            let running = boolValue(row["running"])
                ?? (normalizedState.contains("RUNNING") || normalizedState.contains("ACTIVE"))
            return TrueNASServiceStatus(
                id: stringValue(row["id"]) ?? name,
                name: name,
                state: state,
                enabled: boolValue(row["enable"]) ?? boolValue(row["enabled"]) ?? false,
                running: running
            )
        }
        .sorted {
            if $0.running != $1.running { return $0.running && !$1.running }
            if $0.enabled != $1.enabled { return $0.enabled && !$1.enabled }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func parseShareSummary(smbObject: Any, nfsObject: Any, iscsiObject: Any) -> TrueNASShareSummary {
        TrueNASShareSummary(
            smbCount: arrayCount(smbObject),
            nfsCount: arrayCount(nfsObject),
            iscsiCount: arrayCount(iscsiObject)
        )
    }

    private static func parseWorkloadSummary(appObject: Any, vmObject: Any) -> TrueNASWorkloadSummary {
        let apps = arrayRows(appObject)
        let vms = arrayRows(vmObject)
        return TrueNASWorkloadSummary(
            appsTotal: apps.count,
            appsRunning: apps.filter { row in
                let state = stringValue(valueForPath(row, path: ["state"]))
                    ?? stringValue(valueForPath(row, path: ["status"]))
                    ?? stringValue(valueForPath(row, path: ["metadata", "state"]))
                    ?? ""
                let activeWorkloads = doubleValue(valueForPath(row, path: ["active_workloads"])) ?? 0
                let normalized = state.uppercased()
                return activeWorkloads > 0 || normalized.contains("RUNNING") || normalized.contains("ACTIVE")
            }.count,
            virtualMachinesTotal: vms.count,
            virtualMachinesRunning: vms.filter { row in
                let state = stringValue(valueForPath(row, path: ["status", "state"]))
                    ?? stringValue(valueForPath(row, path: ["state"]))
                    ?? stringValue(valueForPath(row, path: ["status"]))
                    ?? ""
                return state.uppercased().contains("RUNNING")
            }.count
        )
    }

    // MARK: - Value helpers

    private static func cleanURL(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }
        let trailing = CharacterSet(charactersIn: ")]},;")
        while let last = clean.unicodeScalars.last, trailing.contains(last) {
            clean = String(clean.dropLast())
        }
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") && !clean.hasPrefix("ws://") && !clean.hasPrefix("wss://") {
            clean = "https://" + clean
        }
        return clean.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    private static func stringValue(_ raw: Any?) -> String? {
        switch raw {
        case let value as String:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let value as Int:
            return "\(value)"
        case let value as Double:
            return value.isFinite ? "\(value)" : nil
        case let value as Bool:
            return value ? "true" : "false"
        default:
            return nil
        }
    }

    private static func doubleValue(_ raw: Any?) -> Double? {
        switch raw {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func boolValue(_ raw: Any?) -> Bool? {
        switch raw {
        case let value as Bool:
            return value
        case let value as String:
            let normalized = value.lowercased()
            if ["true", "yes", "online", "healthy"].contains(normalized) { return true }
            if ["false", "no", "offline", "faulted", "degraded"].contains(normalized) { return false }
            return nil
        default:
            return nil
        }
    }

    private static func arrayRows(_ raw: Any) -> [[String: Any]] {
        if let rows = raw as? [[String: Any]] {
            return rows
        }
        if let dict = raw as? [String: Any] {
            for key in ["rows", "data", "items", "results", "result", "response"] {
                if let rows = dict[key] as? [[String: Any]] {
                    return rows
                }
            }
        }
        return []
    }

    private static func arrayCount(_ raw: Any) -> Int {
        if let rows = raw as? [Any] {
            return rows.count
        }
        return arrayRows(raw).count
    }

    private static func valueForPath(_ raw: [String: Any], path: [String]) -> Any? {
        var current: Any? = raw
        for key in path {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[key]
        }
        return current
    }

    private static func errorMessage(from raw: Any) -> String {
        if let text = raw as? String {
            return text
        }
        if let dict = raw as? [String: Any] {
            if let message = stringValue(dict["message"]) {
                return message
            }
            if let reason = stringValue((dict["data"] as? [String: Any])?["reason"]) {
                return reason
            }
            if let error = stringValue(dict["error"]) {
                return error
            }
        }
        return "TrueNAS API request failed"
    }

    private static func formatUptimeSeconds(_ raw: String) -> String {
        guard let seconds = Double(raw) else { return raw }
        let days = Int(seconds / 86_400)
        let hours = Int((seconds.truncatingRemainder(dividingBy: 86_400)) / 3_600)
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3_600)) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
