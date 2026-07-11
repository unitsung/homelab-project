import Foundation
import os
import Observation

/// A centralized structured logger for the Homelab application.
///
/// Logs go to:
/// 1. Apple unified logging (`os.Logger`) — readable via Console / `log show`
/// 2. In-memory `LogStore` — Settings → Debug Logs UI
/// 3. On-disk `homelab-debug.log` — Application Support + Documents (agent / simctl can pull)
public struct AppLogger: Sendable {
    public static let shared = AppLogger()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.homelab.app", category: "General")

    public func debug(_ message: String, source: String = "App") {
        logger.debug("\(message, privacy: .public)")
        Task { @MainActor in
            LogStore.shared.add(message, level: .debug, source: source)
        }
    }

    public func info(_ message: String, source: String = "App") {
        logger.info("\(message, privacy: .public)")
        Task { @MainActor in
            LogStore.shared.add(message, level: .info, source: source)
        }
    }

    public func warn(_ message: String, source: String = "App") {
        logger.warning("\(message, privacy: .public)")
        Task { @MainActor in
            LogStore.shared.add(message, level: .warn, source: source)
        }
    }

    public func error(_ message: String, source: String = "App") {
        logger.error("\(message, privacy: .public)")
        Task { @MainActor in
            LogStore.shared.add(message, level: .error, source: source)
        }
    }

    public func error(_ error: Error, source: String = "App") {
        let msg = "Error: \(error.localizedDescription)"
        logger.error("\(msg, privacy: .public)")
        Task { @MainActor in
            LogStore.shared.add(msg, level: .error, source: source)
        }
    }

    public func network(_ message: String, source: String = "Network") {
        logger.info("[Network] \(message, privacy: .public)")
        Task { @MainActor in
            LogStore.shared.add(message, level: .network, source: source)
        }
    }

    /// Logs state transitions for ViewModels using LoadableState
    public func stateTransition<T>(service: String, state: LoadableState<T>) {
        let stateString: String
        switch state {
        case .idle: stateString = "Idle"
        case .loading: stateString = "Loading"
        case .loaded: stateString = "Loaded"
        case .error(let err): stateString = "Error (\(err.errorDescription ?? "unknown"))"
        case .offline: stateString = "Offline"
        }
        let msg = "[\(service)] State Transition -> \(stateString)"
        logger.debug("\(msg, privacy: .public)")
        Task { @MainActor in
            LogStore.shared.add(msg, level: .debug, source: service)
        }
    }
}

// MARK: - LogStore

@MainActor
@Observable
public final class LogStore {
    public static let shared = LogStore()

    public struct LogEntry: Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let level: LogLevel
        public let source: String
        public let message: String

        public init(level: LogLevel, message: String, source: String = "App", timestamp: Date = Date(), id: UUID = UUID()) {
            self.id = id
            self.timestamp = timestamp
            self.level = level
            self.source = source
            self.message = message
        }

        private static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f
        }()

        public var formattedTime: String {
            Self.timeFormatter.string(from: timestamp)
        }

        public var fileLine: String {
            "[\(formattedTime)] [\(level.rawValue)] [\(source)] \(message)"
        }
    }

    public enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
        case network = "NET"

        public var icon: String {
            switch self {
            case .debug: return "ladybug.fill"
            case .info: return "info.circle.fill"
            case .warn: return "exclamationmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .network: return "network"
            }
        }
    }

    public private(set) var entries: [LogEntry] = []
    /// Disk file paths (for Debug UI + external tooling).
    public private(set) var primaryLogFileURL: URL?
    public private(set) var documentsLogFileURL: URL?

    private let maxEntries = 1000
    private let maxFileBytes = 1_500_000
    private var lastEmissionByKey: [String: Date] = [:]
    private let fileQueue = DispatchQueue(label: "com.homelab.logstore.file", qos: .utility)

    private init() {
        configureFileURLs()
        loadRecentFromDisk()
        add("LogStore ready. file=\(primaryLogFileURL?.path ?? "nil")", level: .info, source: "LogStore")
    }

    public func add(_ message: String, level: LogLevel = .info, source: String = "App") {
        let now = Date()
        // Never drop OpenList / error / warn — needed for remote debugging of 401/500.
        let isCriticalSource = source.localizedCaseInsensitiveContains("OpenList")
            || source.localizedCaseInsensitiveContains("LogStore")
        if !isCriticalSource, shouldDrop(level: level, message: message, now: now) {
            return
        }

        let entry = LogEntry(level: level, message: message, source: source, timestamp: now)
        entries.append(entry)

        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        persist(entry)
    }

    public func clear() {
        entries.removeAll()
        fileQueue.async { [primaryLogFileURL, documentsLogFileURL] in
            for url in [primaryLogFileURL, documentsLogFileURL].compactMap({ $0 }) {
                try? Data().write(to: url, options: .atomic)
            }
        }
    }

    public func export() -> String {
        entries.map(\.fileLine).joined(separator: "\n")
    }

    /// Absolute paths for share / agent pull.
    public func logFilePathsDescription() -> String {
        [
            primaryLogFileURL.map { "AppSupport: \($0.path)" },
            documentsLogFileURL.map { "Documents: \($0.path)" },
            hostMirrorLogFileURL.map { "HostMirror: \($0.path)" }
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    // MARK: - Disk

    /// Extra mirror for My Mac (Designed for iPad) / agent pull — outside app sandbox when allowed.
    /// iOS-App-on-Mac often can write here via temporary/shared paths we also try.
    public private(set) var hostMirrorLogFileURL: URL?

    private func configureFileURLs() {
        let fm = FileManager.default
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = support.appendingPathComponent("Homelab", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            primaryLogFileURL = dir.appendingPathComponent("homelab-debug.log")
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsLogFileURL = docs.appendingPathComponent("homelab-debug.log")
        }

        // My Mac (Designed for iPad): mirror into a fixed host path so agents can `cat` without simctl.
        // ProcessInfo.isiOSAppOnMac is true for this run mode.
        if ProcessInfo.processInfo.isiOSAppOnMac {
            let mirrorDir = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Logs/Homelab", isDirectory: true)
            try? fm.createDirectory(at: mirrorDir, withIntermediateDirectories: true)
            hostMirrorLogFileURL = mirrorDir.appendingPathComponent("homelab-debug.log")
            // Also try project tmp if developer runs from this machine (best-effort; may fail sandbox).
            let projectTmp = URL(fileURLWithPath: "/Users/unitsung/Documents/Code/homelab-project/tmp", isDirectory: true)
            try? fm.createDirectory(at: projectTmp, withIntermediateDirectories: true)
            // Prefer project tmp when writable; keep Library/Logs as primary host mirror.
            if fm.isWritableFile(atPath: projectTmp.path) || (try? fm.createDirectory(at: projectTmp, withIntermediateDirectories: true)) != nil {
                let projectLog = projectTmp.appendingPathComponent("homelab-debug.log")
                // Test write
                if fm.createFile(atPath: projectLog.path, contents: nil) || fm.isWritableFile(atPath: projectLog.path) {
                    hostMirrorLogFileURL = projectLog
                }
            }
        }
    }

    private func loadRecentFromDisk() {
        guard let url = primaryLogFileURL ?? documentsLogFileURL,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else { return }

        // Keep last ~200 lines for UI bootstrap after relaunch.
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).suffix(200)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        // We only restore message text; timestamps re-parsed loosely.
        for line in lines {
            let s = String(line)
            guard s.count > 10 else { continue }
            entries.append(
                LogEntry(level: .info, message: s, source: "Disk", timestamp: Date())
            )
        }
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
    }

    private func persist(_ entry: LogEntry) {
        let line = entry.fileLine + "\n"
        let urls = [primaryLogFileURL, documentsLogFileURL, hostMirrorLogFileURL].compactMap { $0 }
        let maxBytes = maxFileBytes
        fileQueue.async {
            guard let payload = line.data(using: .utf8) else { return }
            for url in urls {
                Self.appendLogLine(payload, line: line, to: url, maxBytes: maxBytes)
            }
        }
    }

    private static func appendLogLine(_ payload: Data, line: String, to url: URL, maxBytes: Int) {
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: payload)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? NSNumber,
               size.intValue > maxBytes,
               let data = try? Data(contentsOf: url) {
                let trimmed = data.suffix(maxBytes / 2)
                try? Data(trimmed).write(to: url, options: .atomic)
            }
        } catch {
            if let existing = try? String(contentsOf: url, encoding: .utf8) {
                try? (existing + line).data(using: .utf8)?.write(to: url, options: .atomic)
            } else {
                try? payload.write(to: url, options: .atomic)
            }
        }
    }

    private func shouldDrop(level: LogLevel, message: String, now: Date) -> Bool {
        let minInterval: TimeInterval
        switch level {
        case .network:
            minInterval = 2.0
        case .debug:
            minInterval = 0.8
        case .info, .warn, .error:
            return false
        }

        let key = "\(level.rawValue)|\(message)"
        if let last = lastEmissionByKey[key], now.timeIntervalSince(last) < minInterval {
            return true
        }

        lastEmissionByKey[key] = now

        if lastEmissionByKey.count > 1200 {
            let threshold = now.addingTimeInterval(-120)
            lastEmissionByKey = lastEmissionByKey.filter { $0.value >= threshold }
        }
        return false
    }
}
