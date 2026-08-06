import Foundation

/// Source of Info.plist string values (production: `Bundle.main`).
protocol InfoDictionaryProviding {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: InfoDictionaryProviding {}

/// Resolves in-app update endpoints from Info.plist.
///
/// Keys:
/// - `HomelabUpdateManifestURL` — JSON feed (e.g. app-version.json). Blank disables the check.
/// - `HomelabUpdateDefaultURL` — fallback release / download page.
enum UpdateFeedConfiguration {
    static let manifestInfoKey = "HomelabUpdateManifestURL"
    static let defaultPageInfoKey = "HomelabUpdateDefaultURL"

    /// Built-in defaults for this personal fork (not upstream JohnnWi).
    static let builtInManifestURLString =
        "https://raw.githubusercontent.com/unitsung/homelab-project/main/app-version.json"
    static let builtInDefaultPageURLString =
        "https://github.com/unitsung/homelab-project/releases"

    /// Returns `nil` when the manifest URL is explicitly empty → skip network update checks.
    static func manifestURL(from info: any InfoDictionaryProviding) -> URL? {
        let raw = string(forKey: manifestInfoKey, in: info)
        // Missing key → use built-in default for this fork.
        // Present but empty/whitespace → disable (private fork / no phone-home).
        if raw == nil {
            return URL(string: builtInManifestURLString)
        }
        let trimmed = raw!.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return URL(string: trimmed)
    }

    static func defaultPageURL(from info: any InfoDictionaryProviding) -> String {
        let raw = string(forKey: defaultPageInfoKey, in: info)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return builtInDefaultPageURLString
    }

    private static func string(forKey key: String, in info: any InfoDictionaryProviding) -> String? {
        info.object(forInfoDictionaryKey: key) as? String
    }
}
