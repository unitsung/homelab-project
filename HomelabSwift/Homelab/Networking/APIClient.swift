import Foundation

// MARK: - Notifications for 401 interception

extension Notification.Name {
    static let serviceUnauthorized = Notification.Name("serviceUnauthorized")
}

// MARK: - Base networking engine (used via composition, NOT inheritance)
// Swift actors cannot inherit from other actors. Each API client actor
// owns a BaseNetworkEngine instance to share the common request logic.

final class BaseNetworkEngine: Sendable {
    let serviceType: ServiceType
    let instanceId: UUID
    private let allowSelfSigned: Bool
    private let timeoutInterval: TimeInterval = 8
    private let pingTimeout: TimeInterval = 3
    /// Image pulls / container updates routinely exceed the normal 8s API budget.
    static let longRunningTimeout: TimeInterval = 300

    // MARK: - Shared delegates & sessions

    private static let insecureDelegate = InsecureTrustDelegate()
    private static let secureDelegate = SecureTrustDelegate()

    static let insecureDelegateForPortainerAuth: URLSessionDelegate = insecureDelegate

    // Insecure sessions (self-signed certs allowed — default for homelab)
    private static let insecureRequestSession: URLSession = {
        makeSession(delegate: insecureDelegate, timeout: 8)
    }()
    private static let insecureLongRequestSession: URLSession = {
        makeSession(delegate: insecureDelegate, timeout: longRunningTimeout)
    }()
    private static let insecurePingSession: URLSession = {
        makeSession(delegate: insecureDelegate, timeout: 3)
    }()
    private static let insecureImageSession: URLSession = {
        makeSession(delegate: insecureDelegate, timeout: 8, cachePolicy: .returnCacheDataElseLoad)
    }()

    // Secure sessions (standard TLS validation — used when allowSelfSigned = false)
    private static let secureRequestSession: URLSession = {
        makeSession(delegate: secureDelegate, timeout: 8)
    }()
    private static let secureLongRequestSession: URLSession = {
        makeSession(delegate: secureDelegate, timeout: longRunningTimeout)
    }()
    private static let securePingSession: URLSession = {
        makeSession(delegate: secureDelegate, timeout: 3)
    }()
    private static let secureImageSession: URLSession = {
        makeSession(delegate: secureDelegate, timeout: 8, cachePolicy: .returnCacheDataElseLoad)
    }()

    private static func makeSession(
        delegate: URLSessionDelegate,
        timeout: TimeInterval,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.requestCachePolicy = cachePolicy
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    static func authSession(allowSelfSigned: Bool, timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        return URLSession(configuration: config, delegate: allowSelfSigned ? insecureDelegate : secureDelegate, delegateQueue: nil)
    }

    init(serviceType: ServiceType, instanceId: UUID, allowSelfSigned: Bool = true) {
        self.serviceType = serviceType
        self.instanceId = instanceId
        self.allowSelfSigned = allowSelfSigned
    }

    // MARK: - Session selection

    private var requestSession: URLSession {
        allowSelfSigned ? Self.insecureRequestSession : Self.secureRequestSession
    }

    private var longRequestSession: URLSession {
        allowSelfSigned ? Self.insecureLongRequestSession : Self.secureLongRequestSession
    }

    private var pingSession: URLSession {
        allowSelfSigned ? Self.insecurePingSession : Self.securePingSession
    }

    private var imageSession: URLSession {
        allowSelfSigned ? Self.insecureImageSession : Self.secureImageSession
    }

    /// Prefer the long-running session when the caller needs more than the default budget.
    /// Session-level resource timeouts must rise too — raising only `URLRequest.timeoutInterval`
    /// cannot exceed `URLSessionConfiguration.timeoutIntervalForResource`.
    private func session(for timeout: TimeInterval) -> URLSession {
        timeout > timeoutInterval ? longRequestSession : requestSession
    }

    static func imageData(from url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await Self.insecureImageSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.custom("Invalid image response")
        }
        guard (200...399).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, body: "")
        }
        return data
    }

    // MARK: - Access mode (LAN vs remote)

    /// Apply global network access mode so only one base is used (no silent dual-try).
    static func endpointsForAccessMode(baseURL: String, fallbackURL: String) -> (baseURL: String, fallbackURL: String) {
        NetworkAccessMode.resolve(primary: baseURL, fallback: fallbackURL)
    }

    // MARK: - Core Request (respects NetworkAccessMode; force single base)

    func request<T: Decodable>(
        baseURL: String,
        fallbackURL: String,
        path: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let endpoints = Self.endpointsForAccessMode(baseURL: baseURL, fallbackURL: fallbackURL)
        guard !endpoints.baseURL.isEmpty else { throw APIError.notConfigured }
        let effectiveTimeout = timeout ?? timeoutInterval

        do {
            return try await performRequest(
                baseURL: endpoints.baseURL,
                path: path,
                method: method,
                headers: headers,
                body: body,
                timeout: effectiveTimeout
            )
        } catch let primaryError {
            guard !endpoints.fallbackURL.isEmpty else { throw primaryError }
            do {
                return try await performRequest(
                    baseURL: endpoints.fallbackURL,
                    path: path,
                    method: method,
                    headers: headers,
                    body: body,
                    timeout: effectiveTimeout
                )
            } catch let fallbackError {
                throw APIError.bothURLsFailed(primaryError: primaryError, fallbackError: fallbackError)
            }
        }
    }

    /// Request that returns raw String (for logs)
    func requestString(
        baseURL: String,
        fallbackURL: String,
        path: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> String {
        let endpoints = Self.endpointsForAccessMode(baseURL: baseURL, fallbackURL: fallbackURL)
        guard !endpoints.baseURL.isEmpty else { throw APIError.notConfigured }

        do {
            return try await performStringRequest(baseURL: endpoints.baseURL, path: path, method: method, headers: headers, body: body)
        } catch let primaryError {
            guard !endpoints.fallbackURL.isEmpty else { throw primaryError }
            do {
                return try await performStringRequest(baseURL: endpoints.fallbackURL, path: path, method: method, headers: headers, body: body)
            } catch let fallbackError {
                throw APIError.bothURLsFailed(primaryError: primaryError, fallbackError: fallbackError)
            }
        }
    }

    /// Request that ignores response body (for actions like start/stop)
    func requestVoid(
        baseURL: String,
        fallbackURL: String,
        path: String,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws {
        let endpoints = Self.endpointsForAccessMode(baseURL: baseURL, fallbackURL: fallbackURL)
        guard !endpoints.baseURL.isEmpty else { throw APIError.notConfigured }

        do {
            try await performVoidRequest(baseURL: endpoints.baseURL, path: path, method: method, headers: headers, body: body)
        } catch let primaryError {
            guard !endpoints.fallbackURL.isEmpty else { throw primaryError }
            do {
                try await performVoidRequest(baseURL: endpoints.fallbackURL, path: path, method: method, headers: headers, body: body)
            } catch let fallbackError {
                throw APIError.bothURLsFailed(primaryError: primaryError, fallbackError: fallbackError)
            }
        }
    }

    /// Request that returns raw Data (for PiHole dynamic JSON parsing)
    func requestData(
        baseURL: String,
        fallbackURL: String,
        path: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> Data {
        let endpoints = Self.endpointsForAccessMode(baseURL: baseURL, fallbackURL: fallbackURL)
        guard !endpoints.baseURL.isEmpty else { throw APIError.notConfigured }
        let effectiveTimeout = timeout ?? timeoutInterval

        do {
            return try await performDataRequest(
                baseURL: endpoints.baseURL,
                path: path,
                method: method,
                headers: headers,
                body: body,
                timeout: effectiveTimeout
            )
        } catch let primaryError {
            guard !endpoints.fallbackURL.isEmpty else { throw primaryError }
            do {
                return try await performDataRequest(
                    baseURL: endpoints.fallbackURL,
                    path: path,
                    method: method,
                    headers: headers,
                    body: body,
                    timeout: effectiveTimeout
                )
            } catch let fallbackError {
                throw APIError.bothURLsFailed(primaryError: primaryError, fallbackError: fallbackError)
            }
        }
    }

    // MARK: - Ping Helper

    func pingURL(_ urlString: String, extraHeaders: [String: String] = [:]) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = pingTimeout
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (_, response) = try await pingSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...399).contains(http.statusCode)
        } catch {
            return false
        }
    }

    /// Ping only the base selected by the current network access mode.
    func pingWithAccessMode(
        baseURL: String,
        fallbackURL: String,
        path: String,
        extraHeaders: [String: String] = [:]
    ) async -> Bool {
        let endpoints = Self.endpointsForAccessMode(baseURL: baseURL, fallbackURL: fallbackURL)
        guard !endpoints.baseURL.isEmpty else { return false }
        let suffix = path.hasPrefix("/") || path.isEmpty ? path : "/\(path)"
        return await pingURL(endpoints.baseURL + suffix, extraHeaders: extraHeaders)
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(
        baseURL: String,
        path: String,
        method: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> T {
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        req.httpBody = body

        logRequest(req)
        let (data, response) = try await session(for: timeout).data(for: req)
        logResponse(response, data: data)
        try interceptResponse(response, data: data, expectJSON: true)

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performStringRequest(
        baseURL: String,
        path: String,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> String {
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeoutInterval
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        req.httpBody = body

        logRequest(req)
        let (data, response) = try await requestSession.data(for: req)
        logResponse(response, data: data)
        // Logs/text may be plain; do not treat HTML body as login-page error.
        try interceptResponse(response, data: data, expectJSON: false)

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func performVoidRequest(
        baseURL: String,
        path: String,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws {
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeoutInterval
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        req.httpBody = body

        logRequest(req)
        let (data, response) = try await requestSession.data(for: req)
        logResponse(response, data: data)
        try interceptResponse(response, data: data, expectJSON: false)
    }

    private func performDataRequest(
        baseURL: String,
        path: String,
        method: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> Data {
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        req.httpBody = body

        logRequest(req)
        let (data, response) = try await session(for: timeout).data(for: req)
        logResponse(response, data: data)
        // File downloads / OpenList /p proxy may return text/html for real HTML files.
        try interceptResponse(response, data: data, expectJSON: false)
        return data
    }

    private func logRequest(_ request: URLRequest) {
        let url = request.url?.absoluteString ?? "unknown"
        let method = request.httpMethod ?? "GET"
        AppLogger.shared.network("--> \(method) \(url)", source: serviceType.displayName)
    }

    private func logResponse(_ response: URLResponse, data: Data?) {
        guard let http = response as? HTTPURLResponse else { return }
        let url = response.url?.absoluteString ?? "unknown"
        let status = http.statusCode
        let size = data?.count ?? 0
        let msg = "<-- \(status) \(url) (\(size) bytes)"
        if status >= 400 {
            AppLogger.shared.warn(msg, source: serviceType.displayName)
        } else {
            AppLogger.shared.network(msg, source: serviceType.displayName)
        }
    }

    private func interceptResponse(_ response: URLResponse, data: Data? = nil, expectJSON: Bool = true) throws {
        guard let http = response as? HTTPURLResponse else { return }

        // Only for JSON API calls: HTML body usually means SSO/login interstitial.
        // Raw downloads (OpenList /p text/html files, logs, etc.) must not hit this.
        if expectJSON,
           let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("text/html") {
            let bodySnippet = data.flatMap { String(data: $0.prefix(500), encoding: .utf8) } ?? ""
            if bodySnippet.lowercased().contains("<html") {
                 throw APIError.custom("Received an HTML response instead of JSON. This often happens when the service is behind a login page or proxy (OAuth/SSO). Please check your configuration.")
            }
        }

        if http.statusCode == 401 {
            let type = serviceType
            let instanceId = instanceId
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .serviceUnauthorized,
                    object: nil,
                    userInfo: [
                        "serviceType": type,
                        "instanceId": instanceId
                    ]
                )
            }
            throw APIError.unauthorized
        }

        if http.statusCode >= 400 {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}

final class InsecureTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// Standard TLS validation — rejects self-signed / expired / mismatched certificates.
/// Used when `allowSelfSigned = false` on the service instance.
final class SecureTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let protectionSpace = challenge.protectionSpace
        guard let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Evaluate the server trust using the default system SecTrust evaluation
        var error: CFError?
        let trustResult = SecTrustEvaluateWithError(serverTrust, &error)

        if trustResult {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            // Certificate is invalid (self-signed, expired, wrong host, etc.)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Encoding helpers

extension Encodable {
    func toJSONData() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    func toJSONBody() -> Data? {
        return try? JSONEncoder().encode(self)
    }
}
