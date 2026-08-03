import Foundation
import SwiftUI

// MARK: - Instance settings (UserDefaults; not secrets)

/// Per-instance preferences. Folder CIDs are **never** hardcoded app constants —
/// they come from `/api/cloud115|quark/folders` and the user picks a default.
struct CloudSaverSettings: Equatable, Hashable, Sendable {
    /// Default 115 save target (used by 「想看」).
    var defaultFolder115Cid: String
    var defaultFolder115Name: String
    /// Default Quark save target (detail one-tap default only; no 「想看」 for Quark).
    var defaultFolderQuarkCid: String
    var defaultFolderQuarkName: String
    var libraryOpenURL: String
    var ingestHint: String
    /// CloudSaver plugin id for `POST /api/plugins/run` after save (e.g. LitePan). Empty/0 = skip.
    var postSavePluginId: String

    static let empty = CloudSaverSettings(
        defaultFolder115Cid: "",
        defaultFolder115Name: "",
        defaultFolderQuarkCid: "",
        defaultFolderQuarkName: "",
        libraryOpenURL: "",
        ingestHint: "",
        postSavePluginId: ""
    )

    /// Parsed plugin id when > 0; nil means do not call `/api/plugins/run`.
    var resolvedPostSavePluginId: Int? {
        let t = postSavePluginId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = Int(t), n > 0 else { return nil }
        return n
    }

    enum Category: String, CaseIterable, Sendable {
        case movie, tv, anime
    }

    func defaultFolder(for cloud: CloudSaverCloudType) -> (cid: String, name: String)? {
        switch cloud {
        case .cloud115:
            let c = defaultFolder115Cid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !c.isEmpty else { return nil }
            let n = defaultFolder115Name.trimmingCharacters(in: .whitespacesAndNewlines)
            return (c, n.isEmpty ? c : n)
        case .quark:
            let c = defaultFolderQuarkCid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !c.isEmpty else { return nil }
            let n = defaultFolderQuarkName.trimmingCharacters(in: .whitespacesAndNewlines)
            return (c, n.isEmpty ? c : n)
        case .unknown:
            return nil
        }
    }

    mutating func setDefaultFolder(cloud: CloudSaverCloudType, cid: String, name: String) {
        let c = cid.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch cloud {
        case .cloud115:
            defaultFolder115Cid = c
            defaultFolder115Name = n.isEmpty ? c : n
        case .quark:
            defaultFolderQuarkCid = c
            defaultFolderQuarkName = n.isEmpty ? c : n
        case .unknown:
            break
        }
    }
}

extension CloudSaverSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case defaultFolder115Cid, defaultFolder115Name
        case defaultFolderQuarkCid, defaultFolderQuarkName
        case libraryOpenURL, ingestHint, postSavePluginId
        // legacy keys (migration)
        case folder115Movie, folder115TV, folder115Anime
        case folderQuarkMovie, folderQuarkTV, folderQuarkAnime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        libraryOpenURL = try c.decodeIfPresent(String.self, forKey: .libraryOpenURL) ?? ""
        ingestHint = try c.decodeIfPresent(String.self, forKey: .ingestHint) ?? ""
        postSavePluginId = try c.decodeIfPresent(String.self, forKey: .postSavePluginId) ?? ""

        func nonEmpty(_ key: CodingKeys) throws -> String? {
            guard let s = try c.decodeIfPresent(String.self, forKey: key) else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        if let d115 = try nonEmpty(.defaultFolder115Cid) {
            defaultFolder115Cid = d115
            defaultFolder115Name = try nonEmpty(.defaultFolder115Name) ?? d115
        } else {
            // migrate first non-empty legacy 115 slot
            let migrated = try nonEmpty(.folder115Movie)
                ?? nonEmpty(.folder115TV)
                ?? nonEmpty(.folder115Anime)
                ?? ""
            defaultFolder115Cid = migrated
            defaultFolder115Name = migrated
        }

        if let dq = try nonEmpty(.defaultFolderQuarkCid) {
            defaultFolderQuarkCid = dq
            defaultFolderQuarkName = try nonEmpty(.defaultFolderQuarkName) ?? dq
        } else {
            let migrated = try nonEmpty(.folderQuarkMovie)
                ?? nonEmpty(.folderQuarkTV)
                ?? nonEmpty(.folderQuarkAnime)
                ?? ""
            defaultFolderQuarkCid = migrated
            defaultFolderQuarkName = migrated
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(defaultFolder115Cid, forKey: .defaultFolder115Cid)
        try c.encode(defaultFolder115Name, forKey: .defaultFolder115Name)
        try c.encode(defaultFolderQuarkCid, forKey: .defaultFolderQuarkCid)
        try c.encode(defaultFolderQuarkName, forKey: .defaultFolderQuarkName)
        try c.encode(libraryOpenURL, forKey: .libraryOpenURL)
        try c.encode(ingestHint, forKey: .ingestHint)
        try c.encode(postSavePluginId, forKey: .postSavePluginId)
    }
}

enum CloudSaverSettingsStore {
    private static func key(for instanceId: UUID) -> String {
        "cloudsaver.settings.\(instanceId.uuidString)"
    }

    static func load(instanceId: UUID) -> CloudSaverSettings {
        guard let data = UserDefaults.standard.data(forKey: key(for: instanceId)),
              let decoded = try? JSONDecoder().decode(CloudSaverSettings.self, from: data)
        else {
            return .empty
        }
        return decoded
    }

    static func save(_ settings: CloudSaverSettings, instanceId: UUID) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key(for: instanceId))
    }
}

// MARK: - Tab / Douban chips

enum CloudSaverMainTab: String, CaseIterable, Identifiable, Sendable {
    case douban
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .douban: return "豆瓣榜单"
        case .search: return "资源搜索"
        }
    }
}

/// Maps web chips → GET /api/douban/hot?type=&category=&api=&limit=
/// Real instance example: type=全部&category=热门&api=movie&limit=50
struct CloudSaverDoubanChip: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// Query `type` — often 全部
    let type: String
    /// Query `category` — 热门 / 最新 / 冷门佳片 / 国产剧 …
    let category: String
    /// Query `api` — movie / tv / …
    let api: String

    static let all: [CloudSaverDoubanChip] = [
        // Movies — matches /douban?type=全部&category=热门&api=movie and /api/douban/hot?...
        .init(id: "movie-hot", title: "热门电影", type: "全部", category: "热门", api: "movie"),
        .init(id: "movie-new", title: "最新电影", type: "全部", category: "最新", api: "movie"),
        .init(id: "movie-cold", title: "冷门佳片", type: "全部", category: "冷门佳片", api: "movie"),
        // TV — real routes use type slugs + category=tv&api=tv
        .init(id: "tv-hot", title: "热门电视剧", type: "tv", category: "tv", api: "tv"),
        .init(id: "tv-cn", title: "热门国产剧", type: "tv_domestic", category: "tv", api: "tv"),
        .init(id: "tv-eu", title: "热门欧美剧", type: "tv_american", category: "tv", api: "tv"),
        .init(id: "tv-kr", title: "热门韩剧", type: "tv_korean", category: "tv", api: "tv"),
        .init(id: "tv-jp", title: "热门日剧", type: "tv_japanese", category: "tv", api: "tv"),
        .init(id: "tv-anime", title: "热门动画", type: "tv_animation", category: "tv", api: "tv"),
        .init(id: "tv-show", title: "热门综艺", type: "tv_show", category: "tv", api: "tv"),
        .init(id: "tv-doc", title: "热门纪录片", type: "tv_documentary", category: "tv", api: "tv"),
    ]

    static let `default` = all[0]
}

struct CloudSaverDoubanItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let rate: String
    let cover: String
    let url: String
    let subtitle: String
    let isNew: Bool
    /// Rating sample size (评分人数)
    let ratingCount: Int
    /// Corner tag e.g. 推荐 / 一般
    let honorTag: String
    /// Mouthpiece label e.g. 口碑极佳 / 高分推荐
    let reputation: String
    /// Year extracted from subtitle when possible
    let year: Int?

    /// Derive 口碑 from numeric rate.
    static func reputation(forRate rate: String) -> String {
        let n = Double(rate) ?? 0
        if n >= 9 { return "口碑极佳" }
        if n >= 8 { return "高分推荐" }
        if n >= 7 { return "值得一看" }
        if n >= 6 { return "口碑一般" }
        if n > 0 { return "口碑较差" }
        return ""
    }

    static func honorTag(forRate rate: String, isNew: Bool) -> String {
        if isNew { return "新上榜" }
        let n = Double(rate) ?? 0
        if n >= 8.5 { return "强烈推荐" }
        if n >= 7.5 { return "推荐" }
        if n >= 6 { return "一般" }
        if n > 0 { return "慎入" }
        return ""
    }

    static func year(from subtitle: String) -> Int? {
        // "2025 / 美国 / 恐怖"
        if let r = try? NSRegularExpression(pattern: #"(19|20)\d{2}"#),
           let m = r.firstMatch(in: subtitle, range: NSRange(subtitle.startIndex..., in: subtitle)),
           let range = Range(m.range, in: subtitle) {
            return Int(subtitle[range])
        }
        return nil
    }
}

// MARK: - Unified poster card (layout)

struct CloudSaverPosterCard: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case douban(CloudSaverDoubanItem)
        case search(CloudSaverSearchResult)
    }

    let id: String
    let title: String
    let imageURL: String
    let badge: String?
    let subtitle: String?
    let kind: Kind

    init(douban: CloudSaverDoubanItem) {
        id = "douban-\(douban.id)"
        title = douban.title
        imageURL = douban.cover
        badge = douban.rate.isEmpty ? nil : douban.rate
        subtitle = douban.subtitle.isEmpty ? nil : douban.subtitle
        kind = .douban(douban)
    }

    init(search: CloudSaverSearchResult) {
        id = "search-\(search.id)"
        title = search.title
        imageURL = search.imageURL
        badge = search.cloudType == .unknown ? nil : search.cloudType.displayName
        subtitle = search.fileSize.isEmpty ? nil : search.fileSize
        kind = .search(search)
    }
}

enum CloudSaverRateColor {
    static func color(for rate: String) -> Color {
        let n = Double(rate) ?? 0
        if n >= 8 { return Color(hex: "#42b883") }
        if n >= 6 { return Color(hex: "#5853fa") }
        return Color(hex: "#f56c6c")
    }
}

// MARK: - Search / transfer

enum CloudSaverCloudType: String, Sendable, Hashable {
    case cloud115 = "115"
    case quark
    case unknown

    init(parsing raw: String) {
        let n = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if n.contains("115") || n == "cloud115" {
            self = .cloud115
        } else if n.contains("quark") || n.contains("夸克") {
            self = .quark
        } else {
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .cloud115: return "115"
        case .quark: return "夸克"
        case .unknown: return "?"
        }
    }
}

struct CloudSaverSearchResult: Identifiable, Hashable, Sendable {
    var id: String { "\(shareCode)|\(cloudType.rawValue)|\(messageId)" }
    let title: String
    let description: String
    let imageURL: String
    let shareCode: String
    let receiveCode: String
    let cloudType: CloudSaverCloudType
    let fileSize: String
    let channel: String
    let channelId: String
    let pubDate: String
    let messageId: String
    let tags: [String]
    var count: Int

    /// Reconstructed public share link for display / copy.
    var shareURL: String {
        switch cloudType {
        case .cloud115:
            if receiveCode.isEmpty {
                return "https://115.com/s/" + shareCode
            }
            return "https://115.com/s/" + shareCode + "?password=" + receiveCode
        case .quark:
            return "https://pan.quark.cn/s/" + shareCode
        case .unknown:
            return shareCode
        }
    }
}


// MARK: - Post-save plugin (LitePan / hooks)

/// Built-in params for CloudSaver `POST /api/plugins/run`.
struct CloudSaverPluginBuiltInParams: Equatable, Hashable, Sendable, Codable {
    var title: String = ""
    var firstShareUrl: String = ""
    var shareUrlStr: String = ""
    var description: String = ""
    var shareUrl: String = ""
    var shareTitle: String = ""
    var savePath: String = ""
    var saveFid: String = ""
    var shareFid: String = ""

    static func make(
        result: CloudSaverSearchResult,
        saveFolderId: String,
        savePath: String,
        files: [CloudSaverShareFile]
    ) -> CloudSaverPluginBuiltInParams {
        let url = result.shareURL
        let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shareFid = files
            .map { $0.fileId.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        return CloudSaverPluginBuiltInParams(
            title: title,
            firstShareUrl: url,
            shareUrlStr: url,
            description: result.description,
            shareUrl: url,
            shareTitle: title,
            savePath: savePath,
            saveFid: saveFolderId,
            shareFid: shareFid
        )
    }
}

/// Outcome of optional post-save plugin after a successful transfer.
enum CloudSaverPostSaveFollowUp: Equatable, Sendable {
    case skipped
    case triggered(message: String)
    case failed(message: String)

    var userSuffix: String? {
        switch self {
        case .skipped:
            return nil
        case .triggered(let message):
            let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return m.isEmpty ? "已触发后续插件（LitePan / STRM / 刷库）" : m
        case .failed(let message):
            let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return m.isEmpty
                ? "已转存，但后续插件触发失败"
                : "已转存，但后续插件触发失败：\(m)"
        }
    }
}

struct CloudSaverSavePathOption: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let folderId: String

    /// User-chosen default folder (from API browse), not hardcoded paths.
    static func defaultOption(for cloud: CloudSaverCloudType, settings: CloudSaverSettings) -> CloudSaverSavePathOption? {
        guard let d = settings.defaultFolder(for: cloud) else { return nil }
        return CloudSaverSavePathOption(id: "default-\(cloud.rawValue)", label: d.name, folderId: d.cid)
    }
}


/// Classifies CloudSaver auth failures: App JWT/session vs pan Cookie.
enum CloudSaverAuthFailure {
    static func isAppSessionAuthError(_ error: Error) -> Bool {
        if let api = error as? APIError {
            switch api {
            case .unauthorized:
                return true
            case .httpError(let code, let body):
                if code == 401 { return true }
                if code == 403 { return looksLikeAppSession(body) }
                return false
            case .custom(let msg):
                return looksLikeAppSession(msg)
            case .bothURLsFailed(let primary, let fallback):
                return isAppSessionAuthError(primary) || isAppSessionAuthError(fallback)
            default:
                return false
            }
        }
        return looksLikeAppSession(error.localizedDescription)
    }

    /// Detect App session/JWT expiry messages. Explicitly excludes pan Cookie wording.
    static func looksLikeAppSession(_ raw: String) -> Bool {
        let t = raw.lowercased()
        if t.contains("cookie") { return false }
        if t.contains("网盘") && (t.contains("过期") || t.contains("失效") || t.contains("登录")) {
            return false
        }
        let keys = [
            "jwt", "bearer", "unauthorized", "unauthorised",
            "token expired", "token invalid", "invalid token", "no token",
            "jwt expired", "jwt malformed", "malformed token",
            "not authenticated", "authentication failed", "access token",
            "未登录", "请先登录", "登录过期", "登录失效", "登录已过期",
            "token过期", "token 过期", "token失效", "token无效", "token 无效",
            "认证失败", "鉴权失败", "身份验证失败", "没有权限", "无有效token",
            "请重新登录", "需要登录", "登录超时"
        ]
        if keys.contains(where: { t.contains($0.lowercased()) || raw.contains($0) }) {
            return true
        }
        if t.contains("401") { return true }
        return false
    }
}

/// Map backend failures to actionable copy.
/// Distinguishes CloudSaver **App** session/JWT expiry from 115/夸克 **Cookie** expiry.
enum CloudSaverUserFacingError {
    static func message(from error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .unauthorized:
                return appSessionMessage
            case .notConfigured:
                return "CloudSaver 尚未配置完整。请在服务设置中填写 URL 与账号密码。"
            default:
                break
            }
        }
        let raw = (error as? APIError)?.errorDescription ?? error.localizedDescription
        return map(raw)
    }

    static func map(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return raw }
        let t = trimmed.lowercased()

        // 1) Pan Cookie — only when wording is clearly about drive cookies / 网盘账号.
        if looksLikePanCookie(t, raw: trimmed) {
            return panCookieMessage
        }

        // 2) App JWT / login session
        if CloudSaverAuthFailure.looksLikeAppSession(trimmed) || looksLikeAppSessionExtra(t) {
            return appSessionMessage
        }

        return trimmed
    }

    private static let appSessionMessage =
        "CloudSaver 登录已过期或无效。若已保存账号密码，App 会自动重新登录；仍失败请到服务设置中重新保存账号密码。"

    private static let panCookieMessage =
        "网盘 Cookie 可能已过期。请到 CloudSaver 网页重新登录 115/夸克 并刷新对应网盘 Cookie 后再试。"

    private static func looksLikePanCookie(_ t: String, raw: String) -> Bool {
        if t.contains("cookie") { return true }
        if t.contains("quark cookie") || t.contains("115 cookie") { return true }
        if raw.contains("网盘账号") || t.contains("网盘 cookie") { return true }
        // e.g. "请先在网页登录夸克/115"
        if (t.contains("夸克") || t.contains("115") || t.contains("网盘"))
            && (t.contains("cookie") || t.contains("网页登录") || t.contains("重新登录网盘")) {
            return true
        }
        return false
    }

    private static func looksLikeAppSessionExtra(_ t: String) -> Bool {
        // Keep narrow extras; primary detection lives on CloudSaverAPIClient.
        let keys = ["unauthorized", "session expired", "session invalid"]
        return keys.contains(where: { t.contains($0) })
    }
}

struct CloudSaverSearchPage: Sendable {
    var results: [CloudSaverSearchResult]
    var hasMore: Bool
    var lastMessageId: String
}

struct CloudSaverRemoteFolder: Identifiable, Hashable, Sendable {
    var id: String { cid }
    let cid: String
    let name: String
}

/// Result of share-info: files plus the receiveCode that save must send.
/// For Quark, this is often the long `stoken` from share-info (not a short password).
struct CloudSaverShareInfoResult: Sendable {
    let files: [CloudSaverShareFile]
    /// Effective receiveCode for subsequent save (may be stoken for Quark).
    let receiveCode: String
}

struct CloudSaverShareFile: Identifiable, Hashable, Sendable {
    var id: String { fileId }
    let fileId: String
    let fileName: String
    let fileSize: Int?
    let fileIdToken: String?
    let isFolder: Bool?
}

enum CloudSaverTransferState: String, Sendable {
    case transferring
    case transferred
    case failed
}

enum CloudSaverCategoryDetector {
    static func detect(from title: String) -> CloudSaverSettings.Category {
        let t = title.lowercased()
        if t.range(of: #"s\d{1,2}e\d{1,2}|第.{1,3}集|连载|更新|\btv\b|电视剧|ep\d{1,3}|全\d+集"#, options: .regularExpression) != nil {
            return .tv
        }
        if t.range(of: #"动漫|动画|anime|ova"#, options: .regularExpression) != nil {
            return .anime
        }
        if t.range(of: #"电影|movie|film"#, options: .regularExpression) != nil {
            return .movie
        }
        return .movie
    }
}
