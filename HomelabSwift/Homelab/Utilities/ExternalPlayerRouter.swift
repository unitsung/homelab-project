import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// External media players we can try to launch with a direct HTTP(S) stream URL.
enum ExternalPlayerOption: String, CaseIterable, Identifiable, Sendable {
    case senPlayer
    case nPlayer
    case vlc
    case infuse
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .senPlayer: return "SenPlayer"
        case .nPlayer: return "nPlayer"
        case .vlc: return "VLC"
        case .infuse: return "Infuse"
        case .system: return "Safari"
        }
    }

    /// SF Symbol used in the player picker (icons only; no third-party brand assets).
    var systemImage: String {
        switch self {
        case .senPlayer: return "play.rectangle.fill"
        case .nPlayer: return "headphones.circle.fill"
        case .vlc: return "play.tv.fill"
        case .infuse: return "film.stack.fill"
        case .system: return "safari.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .senPlayer: return Color(red: 0.55, green: 0.35, blue: 0.95)
        case .nPlayer: return Color(red: 0.95, green: 0.45, blue: 0.15)
        case .vlc: return Color(red: 0.95, green: 0.55, blue: 0.05)
        case .infuse: return Color(red: 0.25, green: 0.45, blue: 0.95)
        case .system: return Color(red: 0.20, green: 0.55, blue: 0.95)
        }
    }

    var detailText: String {
        switch self {
        case .senPlayer: return "Hardware decode · subtitles · MKV"
        case .nPlayer: return "Format-friendly · offline apps"
        case .vlc: return "Open-source · broad codec support"
        case .infuse: return "Library-style · smooth UI"
        case .system: return "Open stream URL in browser"
        }
    }

    /// URL scheme used for `canOpenURL` (must be listed in Info.plist LSApplicationQueriesSchemes).
    var queryScheme: String? {
        switch self {
        case .senPlayer: return "senplayer"
        case .nPlayer: return "nplayer-https"
        case .vlc: return "vlc"
        case .infuse: return "infuse"
        case .system: return nil
        }
    }

    /// Best-effort install check. `system` is always available.
    @MainActor
    var isLikelyInstalled: Bool {
        #if os(iOS)
        guard let scheme = queryScheme,
              let probe = URL(string: "\(scheme)://") else { return true }
        return UIApplication.shared.canOpenURL(probe)
        #else
        return true
        #endif
    }
}

enum ExternalPlayerRouter {
    /// Build candidate open URLs for a player; first that opens wins.
    /// `streamURL` is the OpenList `/d{path}?sign=` link — pass through as absoluteString, no rewrite.
    static func candidateURLs(for player: ExternalPlayerOption, streamURL: URL) -> [URL] {
        let absolute = streamURL.absoluteString
        switch player {
        case .senPlayer:
            var urls: [URL] = []
            // Build query with percentEncodedQuery so we don't double-mangle OpenList's encoding.
            if let u = urlWithQuery(schemeHostPath: "senplayer://x-callback-url/play", name: "url", value: absolute) {
                urls.append(u)
            }
            if let u = urlWithQuery(schemeHostPath: "senplayer://play", name: "url", value: absolute) {
                urls.append(u)
            }
            return urls

        case .nPlayer:
            if var components = URLComponents(url: streamURL, resolvingAgainstBaseURL: false) {
                if components.scheme?.lowercased() == "https" {
                    components.scheme = "nplayer-https"
                } else if components.scheme?.lowercased() == "http" {
                    components.scheme = "nplayer-http"
                }
                if let u = components.url { return [u] }
            }
            return []

        case .vlc:
            var urls: [URL] = []
            if let u = URL(string: "vlc://\(absolute)") { urls.append(u) }
            if let u = urlWithQuery(schemeHostPath: "vlc-x-callback://x-callback-url/stream", name: "url", value: absolute) {
                urls.append(u)
            }
            return urls

        case .infuse:
            if let u = urlWithQuery(schemeHostPath: "infuse://x-callback-url/play", name: "url", value: absolute) {
                return [u]
            }
            return []

        case .system:
            return [streamURL]
        }
    }

    /// `url` query value = OpenList stream URL, percent-encoded once for the query slot only.
    private static func urlWithQuery(schemeHostPath: String, name: String, value: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?+")
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return URL(string: "\(schemeHostPath)?\(name)=\(encodedValue)")
    }

    @MainActor
    static func open(player: ExternalPlayerOption, streamURL: URL) async -> Bool {
        for candidate in candidateURLs(for: player, streamURL: streamURL) {
            if await open(candidate) { return true }
        }
        return false
    }

    @MainActor
    static func openSenPlayer(directURL: URL) async -> Bool {
        await open(player: .senPlayer, streamURL: directURL)
    }

    @MainActor
    static func open(_ url: URL) async -> Bool {
        #if os(iOS)
        return await UIApplication.shared.open(url)
        #elseif os(macOS)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }

    @MainActor
    static func copyToPasteboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
