import Foundation

/// Source of Info.plist string values (production: `Bundle.main`).
protocol InfoDictionaryProviding {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: InfoDictionaryProviding {}

/// In-app update endpoints + **branch isolation**.
///
/// Upstream JohnnWi builds check *their* feed (`JohnnWi/homelab-project`) and use a
/// different bundle id. This fork only accepts updates when:
/// 1. A non-empty `HomelabUpdateManifestURL` is set (this repo’s feed), and
/// 2. The running app’s bundle id is `com.unitsung.myhomelab` (or the value in
///    `HomelabUpdateExpectedBundleID`), and
/// 3. If the feed includes `bundle_id`, it must match the running app.
///
/// So existing upstream installs never consume this fork’s releases, even if someone
/// pointed a custom build at this JSON by mistake.
enum UpdateFeedConfiguration {
    static let manifestInfoKey = "HomelabUpdateManifestURL"
    static let defaultPageInfoKey = "HomelabUpdateDefaultURL"
    static let expectedBundleIDInfoKey = "HomelabUpdateExpectedBundleID"

    /// Bundle id of *this* fork’s signed builds (see Config/Signing.xcconfig).
    static let thisForkBundleID = "com.unitsung.myhomelab"

    /// Default feed for installs built from this branch only.
    static let thisForkManifestURLString =
        "https://raw.githubusercontent.com/unitsung/homelab-project/main/app-version.json"
    static let thisForkDefaultPageURLString =
        "https://github.com/unitsung/homelab-project/releases"

    /// Manifest URL. Empty / missing → no remote check.
    static func manifestURL(from info: any InfoDictionaryProviding) -> URL? {
        guard let raw = string(forKey: manifestInfoKey, in: info) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return URL(string: trimmed)
    }

    static func defaultPageURL(from info: any InfoDictionaryProviding) -> String {
        let raw = string(forKey: defaultPageInfoKey, in: info)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return ""
    }

    /// Bundle id that is allowed to apply this fork’s update feed.
    static func expectedBundleID(from info: any InfoDictionaryProviding) -> String {
        let raw = string(forKey: expectedBundleIDInfoKey, in: info)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return thisForkBundleID
    }

    /// Running app is this fork (or whatever Info.plist declares as expected).
    static func isThisForkInstall(
        runningBundleID: String?,
        info: any InfoDictionaryProviding
    ) -> Bool {
        guard let running = runningBundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !running.isEmpty
        else { return false }
        return running == expectedBundleID(from: info)
    }

    /// Feed may declare `bundle_id`; if present it must equal the running id.
    static func feedTargetsRunningApp(
        feedBundleID: String?,
        runningBundleID: String?
    ) -> Bool {
        guard let running = runningBundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !running.isEmpty
        else { return false }
        guard let feedID = feedBundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !feedID.isEmpty
        else {
            // Legacy feed without bundle_id: still require caller to gate on isThisForkInstall.
            return true
        }
        return feedID == running
    }

    static func isRemoteUpdateConfigured(in info: any InfoDictionaryProviding) -> Bool {
        manifestURL(from: info) != nil
    }

    private static func string(forKey key: String, in info: any InfoDictionaryProviding) -> String? {
        info.object(forInfoDictionaryKey: key) as? String
    }
}
