import SwiftUI
import SwiftTerm
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Session

/// Bridges Arcane's raw PTY WebSocket to an embedded SwiftTerm `TerminalView`.
/// Matches the official Arcane web client (`@xterm/xterm`):
/// - server → client: binary ArrayBuffer decoded as UTF-8, written with ANSI intact
/// - client → server: text frames of keystrokes (xterm `onData`)
@MainActor
final class ArcaneTerminalSession: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var statusMessage: String?

    /// Soft link to the live terminal so receive loop can feed bytes.
    weak var terminalView: TerminalView?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?
    private var pendingOutput: [String] = []

    private let trustDelegate = InsecureTrustDelegate()

    func attach(terminal: TerminalView) {
        terminalView = terminal
        // Drain any bytes that arrived before the view was ready.
        if !pendingOutput.isEmpty {
            for chunk in pendingOutput {
                terminal.feed(text: chunk)
            }
            pendingOutput.removeAll(keepingCapacity: false)
        }
    }

    func connect(
        client: ArcaneAPIClient,
        containerId: String,
        environmentId: String,
        shell: String
    ) async {
        disconnect(notifyUI: false)
        statusMessage = nil

        do {
            let url = try await client.terminalWebSocketURL(
                containerId: containerId,
                environmentId: environmentId,
                shell: shell
            )
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            for (k, v) in await client.currentAuthHeaders() {
                request.setValue(v, forHTTPHeaderField: k)
            }

            let session = URLSession(
                configuration: .default,
                delegate: trustDelegate,
                delegateQueue: nil
            )
            let task = session.webSocketTask(with: request)
            urlSession = session
            webSocketTask = task
            isConnected = true
            task.resume()

            feedLocal("\u{1b}[32m[connected]\u{1b}[0m \(shell)\r\n")

            receiveTask = Task { [weak self] in
                await self?.receiveLoop(task)
            }
        } catch {
            isConnected = false
            statusMessage = error.localizedDescription
            feedLocal("\r\n\u{1b}[31m[error] \(error.localizedDescription)\u{1b}[0m\r\n")
        }
    }

    func disconnect(notifyUI: Bool = true) {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        if isConnected, notifyUI {
            feedLocal("\r\n\u{1b}[33m[disconnected]\u{1b}[0m\r\n")
        }
        isConnected = false
    }

    func clearScreen() {
        // Full reset: clear scrollback + screen, home cursor.
        terminalView?.feed(text: "\u{1b}[2J\u{1b}[3J\u{1b}[H")
        pendingOutput.removeAll(keepingCapacity: false)
    }

    /// Inject local status text (not sent to the remote PTY).
    func feedLocal(_ text: String) {
        if let terminalView {
            terminalView.feed(text: text)
        } else {
            pendingOutput.append(text)
        }
    }

    /// Send keystrokes to the remote PTY (matches Arcane web `ws.send(data)` text frames).
    func sendToRemote(_ data: ArraySlice<UInt8>) {
        guard isConnected, let task = webSocketTask else { return }
        // Prefer text frames like the official xterm client; fall back to binary.
        if let text = String(bytes: data, encoding: .utf8) {
            Task {
                try? await task.send(.string(text))
            }
        } else {
            Task {
                try? await task.send(.data(Data(data)))
            }
        }
    }

    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        sendToRemote(Array(text.utf8)[...])
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled, webSocketTask === task {
            do {
                let message = try await task.receive()
                let text: String
                switch message {
                case .string(let s):
                    text = s
                case .data(let d):
                    // Official Arcane client decodes ArrayBuffer as UTF-8 and writes raw ANSI.
                    text = String(data: d, encoding: .utf8) ?? String(decoding: d, as: UTF8.self)
                @unknown default:
                    text = ""
                }
                guard !text.isEmpty else { continue }
                await MainActor.run {
                    self.feedLocal(text)
                }
            } catch {
                await MainActor.run {
                    guard self.webSocketTask === task else { return }
                    self.isConnected = false
                    self.feedLocal("\r\n\u{1b}[33m[disconnected] \(error.localizedDescription)\u{1b}[0m\r\n")
                    self.webSocketTask = nil
                    self.urlSession?.invalidateAndCancel()
                    self.urlSession = nil
                }
                break
            }
        }
    }

    nonisolated deinit {
        // Best-effort teardown; UI disconnect paths already cancel the session.
    }
}

// MARK: - SwiftUI host

/// Embeds SwiftTerm's UIKit `TerminalView` for true interactive shell input
/// (character-by-character, arrow keys, Ctrl sequences, paste, selection).
struct ArcaneSwiftTermView: UIViewRepresentable {
    @ObservedObject var session: ArcaneTerminalSession
    var fontSize: CGFloat = 13
    var onOpenURL: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, onOpenURL: onOpenURL)
    }

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero)
        view.terminalDelegate = context.coordinator
        view.optionAsMetaKey = true
        view.backgroundColor = UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1) // #09090b
        view.nativeBackgroundColor = UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1)
        view.nativeForegroundColor = UIColor(red: 0.894, green: 0.894, blue: 0.906, alpha: 1) // #e4e4e7
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        view.font = font
        // Become first responder when tapped so soft keyboard drives the PTY directly.
        view.isUserInteractionEnabled = true
        context.coordinator.install(view)
        session.attach(terminal: view)
        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        context.coordinator.session = session
        context.coordinator.onOpenURL = onOpenURL
        if session.terminalView !== uiView {
            session.attach(terminal: uiView)
        }
    }

    static func dismantleUIView(_ uiView: TerminalView, coordinator: Coordinator) {
        uiView.terminalDelegate = nil
        coordinator.session.terminalView = nil
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        var session: ArcaneTerminalSession
        var onOpenURL: ((URL) -> Void)?

        init(session: ArcaneTerminalSession, onOpenURL: ((URL) -> Void)?) {
            self.session = session
            self.onOpenURL = onOpenURL
        }

        func install(_ view: TerminalView) {
            // Ensure keyboard can appear on tap.
            DispatchQueue.main.async {
                _ = view.becomeFirstResponder()
            }
        }

        // MARK: TerminalViewDelegate

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            // Arcane's WebSocket is a raw PTY pipe and does not currently accept resize
            // control frames (same as official web client — local fit only).
            _ = (newCols, newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            // Delegate callbacks are not MainActor; hop before touching the session.
            let bytes = Array(data)
            let session = session
            Task { @MainActor in
                session.sendToRemote(bytes[...])
            }
        }

        func scrolled(source: TerminalView, position: Double) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link) else { return }
            onOpenURL?(url)
        }

        func bell(source: TerminalView) {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }

        func clipboardCopy(source: TerminalView, content: Data) {
            #if canImport(UIKit)
            if let text = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = text
            }
            #endif
        }

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
