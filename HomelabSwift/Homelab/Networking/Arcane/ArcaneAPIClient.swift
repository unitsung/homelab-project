import Foundation

actor ArcaneAPIClient {
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

    func configure(url: String, apiKey: String?, token: String?, fallbackUrl: String?, username: String?, password: String?, allowSelfSigned: Bool?) {
        self.baseURL = Self.cleanURL(url)
        self.fallbackURL = Self.cleanURL(fallbackUrl ?? "")
        if let apiKey, !apiKey.isEmpty { self.apiKey = apiKey }
        if let token, !token.isEmpty { self.jwtToken = token }
        if let username, !username.isEmpty { self.username = username }
        if let password, !password.isEmpty { self.storedPassword = password }
        if let allowSelfSigned { storedAllowSelfSigned = allowSelfSigned }
        engine = BaseNetworkEngine(serviceType: .arcane, instanceId: self.instanceId, allowSelfSigned: self.storedAllowSelfSigned)
    }

    func setTokenRefreshCallback(_ callback: @escaping @Sendable (String) -> Void) {
        self.onTokenRefreshed = callback
    }

    func setAPIKey(_ key: String) {
        self.apiKey = key.isEmpty ? nil : key
    }

    private func authHeaders() -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let apiKey { headers["X-API-Key"] = apiKey }
        else if let jwtToken { headers["Authorization"] = "Bearer \(jwtToken)" }
        return headers
    }

    private static func cleanURL(_ url: String) -> String {
        url.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    func ping() async -> Bool {
        if baseURL.isEmpty { return false }
        if await engine.pingURL("\(baseURL)/api/health", extraHeaders: authHeaders()) { return true }
        if !fallbackURL.isEmpty {
            return await engine.pingURL("\(fallbackURL)/api/health", extraHeaders: authHeaders())
        }
        return false
    }

    func login(username: String, password: String) async throws {
        let response: LoginResponse = try await engine.request(
            baseURL: baseURL, fallbackURL: fallbackURL,
            path: "/api/auth/login",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(["username": username, "password": password])
        )
        self.jwtToken = response.token
        onTokenRefreshed?(response.token)
    }

    struct LoginResponse: Codable { let token: String }

    private func authenticatedRequest<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        do {
            return try await engine.request(baseURL: baseURL, fallbackURL: fallbackURL, path: path, method: method, headers: authHeaders(), body: body)
        } catch {
            if isAuthError(error), let storedUsername = username, let storedPassword = storedPassword {
                try await login(username: storedUsername, password: storedPassword)
                return try await engine.request(baseURL: baseURL, fallbackURL: fallbackURL, path: path, method: method, headers: authHeaders(), body: body)
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

    func getContainers() async throws -> [ArcaneContainer] {
        return try await authenticatedRequest(path: "/api/containers")
    }

    func getContainer(id: String) async throws -> ArcaneContainer {
        return try await authenticatedRequest(path: "/api/containers/\(id)")
    }

    func getContainerStats(id: String) async throws -> ArcaneContainerStats {
        return try await authenticatedRequest(path: "/api/containers/\(id)/stats")
    }

    func getContainerLogs(id: String, tail: Int = 100) async throws -> String {
        return try await engine.requestString(
            baseURL: baseURL, fallbackURL: fallbackURL,
            path: "/api/containers/\(id)/logs?tail=\(tail)",
            headers: authHeaders()
        )
    }

    func containerAction(id: String, action: ContainerAction) async throws {
        let _: EmptyResponse = try await authenticatedRequest(
            path: "/api/containers/\(id)/\(action.rawValue)",
            method: "POST"
        )
    }

    private struct EmptyResponse: Codable {}
}
