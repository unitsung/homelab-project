import SwiftUI
import UIKit

/// Loads posters that often block bare requests (Douban CDN).
/// Prefer CloudSaver `/api/tele-images` proxy when service base is known;
/// fall back to direct fetch with Douban Referer.
struct CloudSaverRemoteImage: View {
    let urlString: String
    var serviceBaseURL: String = ""
    var bearerToken: String = ""
    var allowSelfSigned: Bool = true

    @State private var image: UIImage?
    @State private var failed = false
    @State private var loading = false

    private var loadKey: String {
        "\(urlString)|\(serviceBaseURL)|\(bearerToken)"
    }

    var body: some View {
        // Never propose intrinsic image size — parent owns the frame.
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if failed {
                    placeholder
                } else {
                    ZStack {
                        placeholder
                        ProgressView()
                    }
                }
            }
            .clipped()
            .task(id: loadKey) {
                await load(force: true)
            }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.35), Color.blue.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(AppTheme.textMuted)
        }
    }

    @MainActor
    private func load(force: Bool) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            failed = true
            image = nil
            return
        }
        // http → https for doubanio when possible
        let normalized = Self.normalizeImageURL(trimmed)
        guard let remote = URL(string: normalized) else {
            failed = true
            image = nil
            return
        }

        if !force, image != nil { return }
        if loading { return }
        loading = true
        defer { loading = false }

        // Reset so baseURL arriving later can recover from prior failure
        if force {
            failed = false
        }

        if let data = await Self.fetchData(
            remote: remote,
            serviceBaseURL: serviceBaseURL,
            bearerToken: bearerToken,
            allowSelfSigned: allowSelfSigned
        ), let ui = UIImage(data: data) {
            image = ui
            failed = false
        } else {
            image = nil
            failed = true
        }
    }

    nonisolated private static func normalizeImageURL(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Douban sometimes returns protocol-relative URLs
        if s.hasPrefix("//") {
            s = "https:" + s
        }
        // Prefer https for douban CDN
        if s.hasPrefix("http://") && s.contains("doubanio.com") {
            s = "https://" + s.dropFirst("http://".count)
        }
        return s
    }

    nonisolated private static func isDoubanHost(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        return host.contains("doubanio.com") || host.contains("douban.com")
    }

    nonisolated private static func fetchData(
        remote: URL,
        serviceBaseURL: String,
        bearerToken: String,
        allowSelfSigned: Bool
    ) async -> Data? {
        let base = serviceBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)

        // Douban: try CS proxy first (server can fetch + set Referer)
        if isDoubanHost(remote), !base.isEmpty {
            if let data = await fetchViaCSProxy(
                remote: remote,
                base: base,
                bearerToken: bearerToken,
                allowSelfSigned: allowSelfSigned
            ) {
                return data
            }
        }

        // Direct with browser headers
        if let data = await request(
            url: remote,
            headers: directHeaders(for: remote),
            allowSelfSigned: allowSelfSigned
        ) {
            return data
        }

        // Non-douban or direct failed: try CS proxy as fallback
        if !base.isEmpty {
            if let data = await fetchViaCSProxy(
                remote: remote,
                base: base,
                bearerToken: bearerToken,
                allowSelfSigned: allowSelfSigned
            ) {
                return data
            }
        }

        return nil
    }

    nonisolated private static func fetchViaCSProxy(
        remote: URL,
        base: String,
        bearerToken: String,
        allowSelfSigned: Bool
    ) async -> Data? {
        let encoded = remote.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? remote.absoluteString
        // Logs show /tele-images/; router is under /api → try both shapes
        let candidates = [
            "\(base)/api/tele-images/?url=\(encoded)",
            "\(base)/api/tele-images?url=\(encoded)",
            "\(base)/tele-images/?url=\(encoded)",
            "\(base)/tele-images?url=\(encoded)"
        ]
        var headers: [String: String] = [
            "Accept": "image/*,*/*;q=0.8",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
        ]
        if !bearerToken.isEmpty {
            headers["Authorization"] = "Bearer \(bearerToken)"
        }
        for path in candidates {
            guard let url = URL(string: path) else { continue }
            if let data = await request(url: url, headers: headers, allowSelfSigned: allowSelfSigned) {
                return data
            }
        }
        return nil
    }

    nonisolated private static func directHeaders(for url: URL) -> [String: String] {
        var headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"
        ]
        if isDoubanHost(url) {
            headers["Referer"] = "https://movie.douban.com/"
            headers["Origin"] = "https://movie.douban.com"
        } else if let origin = url.scheme.flatMap({ scheme in
            url.host.map { "\(scheme)://\($0)" }
        }) {
            headers["Referer"] = origin + "/"
        }
        return headers
    }

    nonisolated private static func request(
        url: URL,
        headers: [String: String],
        allowSelfSigned: Bool
    ) async -> Data? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 25
        req.cachePolicy = .returnCacheDataElseLoad
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        let session: URLSession = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 25
            config.timeoutIntervalForResource = 30
            config.httpAdditionalHeaders = ["Accept": "image/*,*/*"]
            if allowSelfSigned {
                return URLSession(
                    configuration: config,
                    delegate: InsecureImageDelegate.shared,
                    delegateQueue: nil
                )
            }
            return URLSession(configuration: config)
        }()

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200...399).contains(http.statusCode),
                  data.count >= 64
            else { return nil }
            // Reject JSON/HTML error bodies
            if let prefix = String(data: data.prefix(32), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               prefix.hasPrefix("{") || prefix.hasPrefix("<") || prefix.hasPrefix("{\"") {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}

private final class InsecureImageDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let shared = InsecureImageDelegate()

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
