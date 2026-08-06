import Foundation

/// Source of Info.plist string values (production: `Bundle.main`).
protocol InfoDictionaryProviding {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: InfoDictionaryProviding {}

/// Resolves in-app update endpoints from Info.plist.
///
/// **Personal-project policy:** updates are opt-in only. There is **no** built-in
/// phone-home URL. Anyone who builds this source without setting the keys gets
/// zero remote update checks — so strangers do not receive *your* release prompts.
///
/// Keys:
/// - `HomelabUpdateManifestURL` — JSON feed URL. Missing / blank → disabled.
/// - `HomelabUpdateDefaultURL` — fallback page when the feed omits `ios_url`.
enum UpdateFeedConfiguration {
    static let manifestInfoKey = "HomelabUpdateManifestURL"
    static let defaultPageInfoKey = "HomelabUpdateDefaultURL"

    /// Returns `nil` unless Info.plist explicitly sets a non-empty manifest URL.
    static func manifestURL(from info: any InfoDictionaryProviding) -> URL? {
        guard let raw = string(forKey: manifestInfoKey, in: info) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return URL(string: trimmed)
    }

    /// Fallback open URL when a feed is configured but omits `ios_url`.
    /// Empty / missing → empty string (caller should not open a bogus releases page).
    static func defaultPageURL(from info: any InfoDictionaryProviding) -> String {
        let raw = string(forKey: defaultPageInfoKey, in: info)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return ""
    }

    /// Whether remote update checking is configured at build time.
    static func isRemoteUpdateConfigured(in info: any InfoDictionaryProviding) -> Bool {
        manifestURL(from: info) != nil
    }

    private static func string(forKey key: String, in info: any InfoDictionaryProviding) -> String? {
        info.object(forInfoDictionaryKey: key) as? String
    }
}
