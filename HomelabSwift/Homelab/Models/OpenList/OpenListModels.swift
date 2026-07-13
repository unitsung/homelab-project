import Foundation

// MARK: - Business models (Views must not depend on raw OpenList JSON)

struct FileItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date?
    let thumbnailURL: URL?
    let contentTypeHint: Int?
}

struct FileDetail: Sendable {
    let item: FileItem
    /// External play / copy: OpenList-hosted `/d…?sign=` (not cloud CDN).
    let playURL: URL?
    /// In-app text/html preview prefers OpenList-hosted content URL (`/p…` or same-host raw_url).
    let contentURL: URL?
    let sign: String?
    /// Server `raw_url` when present (may be OpenList `/p` or external CDN).
    let serverRawURL: String?
}

struct FileBreadcrumb: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let path: String
}

// MARK: - Wire DTOs

struct OpenListEnvelope<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

struct OpenListListData: Decodable {
    let content: [OpenListFsObject]?
    let total: Int?
    let provider: String?
    let write: Bool?
}

/// Wire model for OpenList FsObject / FsGet data.
/// Apifox schema lists sign; runtime `fs/get` also returns `raw_url` (see OpenList FsGetResp).
struct OpenListFsObject: Decodable {
    let name: String
    let size: Int64?
    let is_dir: Bool?
    let modified: String?
    let created: String?
    /// Signature for download authentication (official FsObject.sign).
    let sign: String?
    let thumb: String?
    let type: Int?
    let hashinfo: String?
    /// Present on POST /api/fs/get (FsGetResp.raw_url). Often `/p…` when WebProxy; may be CDN otherwise.
    let raw_url: String?

    var isDirectory: Bool { is_dir == true }
}

struct OpenListSearchData: Decodable {
    let content: [OpenListSearchObject]?
}

struct OpenListSearchObject: Decodable {
    let parent: String?
    let name: String
    let size: Int64?
    let is_dir: Bool?
    let type: Int?
}

struct OpenListMeData: Decodable {
    let id: Int?
    let username: String?
    let base_path: String?
    let role: Int?
}

struct OpenListLoginData: Decodable {
    let token: String
}

// MARK: - Task center (official `/api/task/{type}/…`)

/// OpenList task managers exposed under `/api/task/*` (see server `SetupTaskRoute`).
enum OpenListTaskType: String, CaseIterable, Identifiable, Sendable {
    case copy
    case offlineDownload = "offline_download"
    case offlineDownloadTransfer = "offline_download_transfer"
    case move
    case upload
    case decompress
    case decompressUpload = "decompress_upload"

    var id: String { rawValue }

    /// Path segment after `/api/task/`.
    var apiSegment: String { rawValue }
}

/// Undone vs done lists from OpenList task handlers.
enum OpenListTaskPhase: String, CaseIterable, Identifiable, Sendable {
    case undone
    case done

    var id: String { rawValue }
    var apiSegment: String { rawValue }
}

/// `tache.State` values used by OpenList task responses.
enum OpenListTaskState: Int, Sendable {
    case pending = 0
    case running = 1
    case succeeded = 2
    case canceling = 3
    case canceled = 4
    case errored = 5
    case failing = 6
    case failed = 7
    case waitingRetry = 8
    case beforeRetry = 9

    var isActive: Bool {
        switch self {
        case .pending, .running, .canceling, .errored, .failing, .waitingRetry, .beforeRetry:
            return true
        case .succeeded, .canceled, .failed:
            return false
        }
    }
}

/// Wire DTO for OpenList `TaskInfo` (server/handles/task.go).
struct OpenListTaskDTO: Decodable, Sendable {
    let id: String
    let name: String?
    let creator: String?
    let creator_role: Int?
    let state: Int?
    let status: String?
    let progress: Double?
    let start_time: String?
    let end_time: String?
    let total_bytes: Int64?
    let error: String?
}

/// App model for a single OpenList background task.
struct OpenListTaskInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let creator: String
    let state: OpenListTaskState
    let status: String
    /// 0…100 (OpenList may return NaN → treated as 100 server-side).
    let progress: Double
    let startTime: Date?
    let endTime: Date?
    let totalBytes: Int64
    let error: String
    let type: OpenListTaskType

    var progressFraction: Double {
        let p = progress.isFinite ? progress : 0
        return min(max(p / 100.0, 0), 1)
    }

    static func from(dto: OpenListTaskDTO, type: OpenListTaskType) -> OpenListTaskInfo {
        let state = OpenListTaskState(rawValue: dto.state ?? 0) ?? .pending
        var progress = dto.progress ?? 0
        if progress.isNaN || !progress.isFinite { progress = state == .succeeded ? 100 : 0 }
        return OpenListTaskInfo(
            id: dto.id,
            name: (dto.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            creator: dto.creator ?? "",
            state: state,
            status: (dto.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            progress: progress,
            startTime: Self.parseTime(dto.start_time),
            endTime: Self.parseTime(dto.end_time),
            totalBytes: dto.total_bytes ?? 0,
            error: (dto.error ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            type: type
        )
    }

    private static func parseTime(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        // RFC3339 with/without fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        return nil
    }
}

enum OpenListPath {
    /// Normalize API paths; empty and "/" both mean root. Does not invent server mounts.
    static func normalize(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/" }
        var result = trimmed
        if !result.hasPrefix("/") {
            result = "/" + result
        }
        while result.count > 1, result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    static func join(parent: String, name: String) -> String {
        let base = normalize(parent)
        if base == "/" { return normalize("/" + name) }
        return normalize(base + "/" + name)
    }

    static func parent(of path: String) -> String {
        let normalized = normalize(path)
        if normalized == "/" { return "/" }
        guard let idx = normalized.lastIndex(of: "/") else { return "/" }
        if idx == normalized.startIndex { return "/" }
        return String(normalized[..<idx])
    }

    static func breadcrumbs(for path: String) -> [FileBreadcrumb] {
        let normalized = normalize(path)
        var crumbs: [FileBreadcrumb] = [
            FileBreadcrumb(id: "/", title: "Root", path: "/")
        ]
        guard normalized != "/" else { return crumbs }
        let parts = normalized.split(separator: "/").map(String.init)
        var built = ""
        for part in parts {
            built += "/" + part
            crumbs.append(FileBreadcrumb(id: built, title: part, path: built))
        }
        return crumbs
    }
}

extension FileItem {
    var parentDirectory: String { OpenListPath.parent(of: path) }

    static func from(object: OpenListFsObject, parentPath: String, baseURL: String = "") -> FileItem {
        let path = OpenListPath.join(parent: parentPath, name: object.name)
        return FileItem(
            id: path,
            name: object.name,
            path: path,
            isDirectory: object.isDirectory,
            size: object.size ?? 0,
            modifiedAt: Self.parseDate(object.modified),
            thumbnailURL: Self.resolveThumb(object.thumb, baseURL: baseURL),
            contentTypeHint: object.type
        )
    }

    static func from(search object: OpenListSearchObject) -> FileItem {
        let parent = object.parent ?? "/"
        let path = OpenListPath.join(parent: parent, name: object.name)
        return FileItem(
            id: path,
            name: object.name,
            path: path,
            isDirectory: object.is_dir == true,
            size: object.size ?? 0,
            modifiedAt: nil,
            thumbnailURL: nil,
            contentTypeHint: object.type
        )
    }

    static func from(detail object: OpenListFsObject, path: String, baseURL: String = "") -> FileItem {
        let name: String
        if object.name.isEmpty {
            name = OpenListPath.normalize(path).split(separator: "/").last.map(String.init) ?? path
        } else {
            name = object.name
        }
        return FileItem(
            id: OpenListPath.normalize(path),
            name: name,
            path: OpenListPath.normalize(path),
            isDirectory: object.isDirectory,
            size: object.size ?? 0,
            modifiedAt: Self.parseDate(object.modified),
            thumbnailURL: Self.resolveThumb(object.thumb, baseURL: baseURL),
            contentTypeHint: object.type
        )
    }

    /// OpenList `thumb` may be absolute, protocol-relative, or host-relative.
    static func resolveThumb(_ raw: String?, baseURL: String) -> URL? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("//") {
            let scheme = URL(string: baseURL)?.scheme ?? "https"
            s = "\(scheme):\(s)"
        }
        if s.hasPrefix("http://") || s.hasPrefix("https://") {
            return URL(string: s)
        }
        guard !baseURL.isEmpty else { return URL(string: s) }
        if s.hasPrefix("/") {
            return URL(string: baseURL + s)
        }
        return URL(string: baseURL + "/" + s)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        // Some OpenList responses use "yyyy-MM-dd HH:mm:ss"
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df.date(from: raw)
    }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    /// Mirrors OpenList web preview routing (video / audio / image / text / html / md / pdf).
    var previewKind: FilePreviewKind {
        if isDirectory { return .none }
        // Prefer server type hint when present (FsObject.type).
        if let hint = contentTypeHint {
            switch hint {
            case 2: return .video
            case 3: return .audio
            case 5: return .image
            case 4:
                if Self.markdownExts.contains(fileExtension) { return .markdown }
                if Self.htmlExts.contains(fileExtension) { return .html }
                return .text
            default:
                break
            }
        }
        let ext = fileExtension
        if Self.videoExts.contains(ext) { return .video }
        if Self.audioExts.contains(ext) { return .audio }
        if Self.imageExts.contains(ext) { return .image }
        if Self.markdownExts.contains(ext) { return .markdown }
        if Self.htmlExts.contains(ext) { return .html }
        if ext == "pdf" { return .pdf }
        if Self.textExts.contains(ext) { return .text }
        // Small unknown files can still try as text in the preview UI.
        return .download
    }

    var isPreviewable: Bool {
        switch previewKind {
        case .none: return false
        case .download: return true // still show download/meta + external open
        default: return true
        }
    }

    var systemImageName: String {
        if isDirectory { return "folder.fill" }
        switch previewKind {
        case .video: return "film"
        case .audio: return "music.note"
        case .image: return "photo"
        case .markdown: return "doc.richtext"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .pdf: return "doc.richtext"
        case .download, .none: break
        }
        switch fileExtension {
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc"
        }
    }

    var isVideoOrAudio: Bool {
        previewKind == .video || previewKind == .audio
    }

    var isArchive: Bool {
        ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "cab", "iso"].contains(fileExtension)
    }

    var isEditableText: Bool {
        switch previewKind {
        case .text, .markdown, .html: return true
        default: return false
        }
    }

    private static let videoExts: Set<String> = [
        "mp4", "mkv", "avi", "mov", "m4v", "ts", "flv", "webm", "wmv", "mpeg", "mpg", "m3u8"
    ]
    private static let audioExts: Set<String> = [
        "mp3", "flac", "aac", "wav", "m4a", "ogg", "opus", "wma", "aiff"
    ]
    private static let imageExts: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "avif", "svg", "ico"
    ]
    private static let markdownExts: Set<String> = ["md", "markdown", "mdown"]
    private static let htmlExts: Set<String> = ["html", "htm"]
    /// Includes subtitles / lyrics / configs OpenList web opens as text.
    private static let textExts: Set<String> = [
        "txt", "text", "log", "nfo", "cue", "inf",
        "ass", "ssa", "srt", "vtt", "lrc", "sub",
        "json", "xml", "yaml", "yml", "toml", "ini", "conf", "cfg", "env",
        "csv", "tsv", "plist",
        "js", "ts", "jsx", "tsx", "css", "scss", "less",
        "py", "rb", "go", "rs", "java", "kt", "swift", "c", "cpp", "h", "hpp", "m", "mm",
        "sh", "bash", "zsh", "ps1", "bat", "cmd",
        "sql", "graphql", "proto", "dockerfile", "makefile",
        "gitignore", "editorconfig", "properties"
    ]
}

/// OpenList web-style preview categories.
enum FilePreviewKind: String, Sendable {
    case none
    case video
    case audio
    case image
    case markdown
    case html
    case text
    case pdf
    case download

    var usesStreamURL: Bool {
        switch self {
        case .video, .audio, .image, .pdf, .html, .markdown, .text:
            return true
        case .download, .none:
            return false
        }
    }

    var loadsAsText: Bool {
        switch self {
        case .markdown, .text, .html:
            return true
        default:
            return false
        }
    }
}
