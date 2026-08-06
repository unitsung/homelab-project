import AVFoundation
import MediaPlayer
import SwiftUI
import VLCKit
#if canImport(UIKit)
import UIKit
#endif

/// Full-screen OpenList player powered by open-source **VLCKit** (libVLC).
/// Handles MKV/AVI/HEVC and network streams that AVPlayer cannot decode.
///
/// Gestures (Infuse-style):
/// - Center tap → show/hide chrome
/// - Left vertical drag → brightness
/// - Right vertical drag → system volume
/// - Double-tap left/right → seek ±10s
struct OpenListMediaPlayerView: View {
    let url: URL
    let title: String
    let isAudio: Bool
    /// Optional external subtitle stream (OpenList sibling .srt/.vtt).
    var externalSubtitleURL: URL? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var localizer

    @StateObject private var engine = OpenListVLCEngine()
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?
    /// nil = follow device; true/false = user lock landscape/portrait.
    @State private var lockedLandscape: Bool? = nil
    @State private var brightness: Double = 0.5
    @State private var volume: Float = AVAudioSession.sharedInstance().outputVolume
    @State private var sideHud: SideHUD?
    @State private var dragStartValue: Double = 0
    @State private var hostScreen: UIScreen?
    @State private var systemVolumeWriter = OpenListSystemVolumeWriter()
    @State private var openingExternal: ExternalPlayerOption?
    @State private var showExternalFallback = false
    @State private var errorText: String?
    @State private var isScrubbing = false
    @State private var scrubFraction: Double = 0

    private let rateOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

    /// Legacy pre-check used when the engine was AVPlayer-only.
    /// With VLCKit almost all common containers work — always return false.
    static func isBuiltInUnfriendlyExtension(_ ext: String) -> Bool {
        _ = ext
        return false
    }

    private enum SideHUD: Equatable {
        case brightness(Double)
        case volume(Double)
    }

    var body: some View {
        // Video goes edge-to-edge; chrome stays inside the safe area.
        // Do NOT put GeometryReader + .ignoresSafeArea() on the whole stack —
        // that zeroes safeAreaInsets and parks the close button under the island.
        ZStack {
            Color.black.ignoresSafeArea()

            OpenListHostScreenReader { screen in
                if hostScreen !== screen {
                    hostScreen = screen
                    brightness = Double(screen.brightness)
                }
            }
            .frame(width: 0, height: 0)

            // Must stay in hierarchy for system volume writes (parked off-screen).
            GeometryReader { geo in
                OpenListSystemVolumeView(writer: systemVolumeWriter)
                    .frame(width: 40, height: 40)
                    .position(x: -geo.size.width, y: -geo.size.height)
                    .opacity(0.02)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)

            if let errorText {
                errorBlock(errorText)
                    .padding(.horizontal, 8)
            } else {
                if isAudio {
                    audioBackdrop
                } else {
                    OpenListVLCVideoView(player: engine.player)
                        .ignoresSafeArea()
                }

                if engine.isReady {
                    GeometryReader { geo in
                        sideGestureLayers(size: geo.size)
                    }
                    .ignoresSafeArea()
                }

                if !engine.isReady {
                    loadingChrome
                } else if showControls {
                    controlsOverlay
                        .transition(.opacity)
                }

                if let sideHud {
                    sideHudBadge(sideHud)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .statusBarHidden(false)
        .persistentSystemOverlays(.hidden)
        .animation(.easeInOut(duration: 0.32), value: lockedLandscape)
        .task { await start() }
        .onAppear {
            // Follow device rotation by default (iPhone 17 Pro Dynamic Island friendly).
            lockedLandscape = nil
            applyOrientation(landscape: nil, animated: false)
        }
        .onDisappear {
            engine.stop()
            applyOrientation(landscape: nil, animated: false)
            Task { await Self.deactivateAudioSession() }
        }
        .onChange(of: engine.isPlaying) { _, playing in
            if playing { scheduleHide() } else { showControls = true }
        }
        .onChange(of: engine.failedMessage) { _, msg in
            guard let msg else { return }
            errorText = msg
            showExternalFallback = true
        }
    }

    // MARK: - Surfaces

    private var audioBackdrop: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.9))
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if engine.isReady {
                Text(clock(engine.current) + " / " + clock(engine.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func errorBlock(_ text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: showExternalFallback ? "film.stack" : "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(showExternalFallback ? .white.opacity(0.9) : .yellow)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            if showExternalFallback {
                VStack(spacing: 8) {
                    ForEach([ExternalPlayerOption.senPlayer, .vlc, .infuse, .nPlayer, .system], id: \.id) { option in
                        Button {
                            Task { await openExternal(option) }
                        } label: {
                            HStack {
                                Image(systemName: option.systemImage)
                                Text(option.displayName).fontWeight(.semibold)
                                Spacer()
                                if openingExternal == option {
                                    ProgressView().tint(.white)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(option.accentColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(openingExternal != nil)
                    }
                }
                .padding(.horizontal, 28)
            }

            Button { dismiss() } label: {
                Text(localizer.t.close)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }

    // MARK: - Chrome

    private var loadingChrome: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.15)
            Text(localizer.t.loading)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            if !engine.isPlaying {
                Button { engine.togglePlay() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            bottomBar
        }
        // Gradient may bleed into unsafe areas; chrome itself stays in the safe area.
        .background(
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.16), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizer.t.close)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)

            Menu {
                ForEach([ExternalPlayerOption.senPlayer, .vlc, .infuse, .nPlayer, .system], id: \.id) { option in
                    Button {
                        Task { await openExternal(option) }
                    } label: {
                        Label(option.displayName, systemImage: option.systemImage)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            // Scrub only on release — continuous seek freezes VLC on many streams.
            HStack(spacing: 10) {
                Text(clock(isScrubbing ? scrubFraction * max(engine.duration, 0) : engine.current))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 48, alignment: .leading)
                Slider(
                    value: Binding(
                        get: {
                            if isScrubbing { return scrubFraction }
                            return engine.duration > 0 ? engine.current / engine.duration : 0
                        },
                        set: { scrubFraction = $0 }
                    ),
                    in: 0...1
                ) { editing in
                    if editing {
                        isScrubbing = true
                        scrubFraction = engine.duration > 0 ? engine.current / engine.duration : 0
                    } else {
                        isScrubbing = false
                        engine.seek(toFraction: scrubFraction)
                        scheduleHide()
                    }
                }
                .tint(.white)
                Text(clock(engine.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 48, alignment: .trailing)
            }
            .padding(.horizontal, 14)

            HStack(spacing: 0) {
                toolButton("gobackward.10", label: "-10s") { engine.jump(by: -10) }
                toolButton(engine.isPlaying ? "pause.fill" : "play.fill", label: engine.isPlaying ? localizer.t.actionPause : localizer.t.actionResume) {
                    engine.togglePlay()
                    scheduleHide()
                }
                toolButton("goforward.10", label: "+10s") { engine.jump(by: 10) }

                Menu {
                    ForEach(rateOptions, id: \.self) { r in
                        Button {
                            engine.setRate(r)
                            scheduleHide()
                        } label: {
                            if abs(engine.rate - r) < 0.01 {
                                Label(rateLabel(r), systemImage: "checkmark")
                            } else {
                                Text(rateLabel(r))
                            }
                        }
                    }
                } label: {
                    toolIcon(nil, label: rateLabel(engine.rate), textOnly: true)
                }

                // Show when embedded tracks exist, or when we attached an external sibling.
                if !engine.textTracks.isEmpty || externalSubtitleURL != nil {
                    Menu {
                        Button {
                            engine.deselectSubtitles()
                        } label: {
                            if engine.selectedTextTrackIndex == nil {
                                Label(localizer.t.filesPlayerSubtitleOff, systemImage: "checkmark")
                            } else {
                                Text(localizer.t.filesPlayerSubtitleOff)
                            }
                        }
                        ForEach(Array(engine.textTracks.enumerated()), id: \.offset) { idx, name in
                            Button {
                                engine.selectTextTrack(at: idx)
                            } label: {
                                if engine.selectedTextTrackIndex == idx {
                                    Label(name, systemImage: "checkmark")
                                } else {
                                    Text(name)
                                }
                            }
                        }
                    } label: {
                        toolIcon(
                            "captions.bubble",
                            label: externalSubtitleURL != nil && engine.textTracks.isEmpty
                                ? localizer.t.filesPlayerSubtitleExternal
                                : localizer.t.filesPlayerSubtitleEmbedded,
                            active: engine.selectedTextTrackIndex != nil
                        )
                    }
                }

                if !engine.audioTracks.isEmpty {
                    Menu {
                        ForEach(Array(engine.audioTracks.enumerated()), id: \.offset) { idx, name in
                            Button {
                                engine.selectAudioTrack(at: idx)
                            } label: {
                                if engine.selectedAudioTrackIndex == idx {
                                    Label(name, systemImage: "checkmark")
                                } else {
                                    Text(name)
                                }
                            }
                        }
                    } label: {
                        toolIcon("waveform", label: localizer.t.filesPlayerAudio)
                    }
                }

                Button {
                    // Cycle: follow device → lock landscape → lock portrait → follow.
                    withAnimation(.easeInOut(duration: 0.32)) {
                        if lockedLandscape == nil {
                            lockedLandscape = true
                        } else if lockedLandscape == true {
                            lockedLandscape = false
                        } else {
                            lockedLandscape = nil
                        }
                    }
                    applyOrientation(landscape: lockedLandscape, animated: true)
                    scheduleHide()
                } label: {
                    toolIcon(
                        lockedLandscape == nil
                            ? "iphone"
                            : (lockedLandscape == true ? "rectangle.landscape.rotate" : "rectangle.portrait.rotate"),
                        label: lockedLandscape == nil
                            ? localizer.t.filesPlayerLandscape
                            : (lockedLandscape == true ? localizer.t.filesPlayerLandscape : localizer.t.filesPlayerPortrait)
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func toolButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolIcon(systemName, label: label)
        }
        .buttonStyle(.plain)
    }

    private func toolIcon(_ systemName: String?, label: String, active: Bool = false, textOnly: Bool = false) -> some View {
        VStack(spacing: 4) {
            if textOnly {
                Text(label)
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(height: 22)
            } else if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(active ? Color.accentColor : .white)
                    .frame(height: 22)
            }
            if !textOnly {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(localizer.t.filesPlayerSpeed)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Gestures

    private func sideGestureLayers(size: CGSize) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .gesture(verticalDrag(kind: .brightness, height: size.height))
                .onTapGesture(count: 2) { engine.jump(by: -10) }
                .onTapGesture(count: 1) { handleCenterTap() }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { handleCenterTap() }

            Color.clear
                .contentShape(Rectangle())
                .gesture(verticalDrag(kind: .volume, height: size.height))
                .onTapGesture(count: 2) { engine.jump(by: 10) }
                .onTapGesture(count: 1) { handleCenterTap() }
        }
        .ignoresSafeArea()
    }

    private enum DragKind { case brightness, volume }

    private func verticalDrag(kind: DragKind, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if abs(value.translation.height) < abs(value.translation.width) * 1.2 { return }
                let delta = -value.translation.height / max(height * 0.4, 1)
                switch kind {
                case .brightness:
                    if case .brightness = sideHud {} else { dragStartValue = brightness }
                    let next = min(max(dragStartValue + Double(delta), 0), 1)
                    setBrightness(next)
                    sideHud = .brightness(next)
                case .volume:
                    if case .volume = sideHud {} else {
                        systemVolumeWriter.isAdjusting = true
                        dragStartValue = Double(currentSystemVolume())
                    }
                    let next = min(max(dragStartValue + Double(delta), 0), 1)
                    setVolume(Float(next))
                    sideHud = .volume(next)
                }
            }
            .onEnded { _ in
                systemVolumeWriter.isAdjusting = false
                volume = currentSystemVolume()
                withAnimation(.easeOut(duration: 0.3)) { sideHud = nil }
            }
    }

    private func sideHudBadge(_ hud: SideHUD) -> some View {
        let isBright: Bool
        let value: Double
        let icon: String
        switch hud {
        case .brightness(let v):
            isBright = true
            value = v
            icon = "sun.max.fill"
        case .volume(let v):
            isBright = false
            value = v
            if v < 0.01 { icon = "speaker.slash.fill" }
            else if v < 0.34 { icon = "speaker.wave.1.fill" }
            else if v < 0.67 { icon = "speaker.wave.2.fill" }
            else { icon = "speaker.wave.3.fill" }
        }
        return HStack {
            if isBright {
                edgeMeter(icon: icon, value: value)
                Spacer()
            } else {
                Spacer()
                edgeMeter(icon: icon, value: value)
            }
        }
        .padding(.horizontal, 28)
        .allowsHitTesting(false)
    }

    private func edgeMeter(icon: String, value: Double) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            GeometryReader { g in
                ZStack(alignment: .bottom) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(.white)
                        .frame(height: max(4, g.size.height * value))
                }
            }
            .frame(width: 4, height: 88)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Lifecycle

    @MainActor
    private func start() async {
        errorText = nil
        showExternalFallback = false
        showControls = true
        volume = currentSystemVolume()
        systemVolumeWriter.onExternalChange = { volume = $0 }
        systemVolumeWriter.startObserving()

        await configureAudioSession()
        AppLogger.shared.info("VLC play url=\(url.absoluteString) audio=\(isAudio)", source: "OpenListPlayer")

        engine.play(url: url, externalSubtitleURL: externalSubtitleURL)
    }

    private func handleCenterTap() {
        guard errorText == nil else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            showControls.toggle()
        }
        if showControls { scheduleHide() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard engine.isPlaying, showControls else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled, engine.isPlaying {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
    }

    private func setVolume(_ v: Float) {
        let clamped = max(0, min(1, v))
        volume = clamped
        systemVolumeWriter.setVolume(clamped)
        // Keep VLC at full gain so system volume is the real loudness.
        engine.player.audio?.volume = 100
    }

    private func currentSystemVolume() -> Float {
        let session = AVAudioSession.sharedInstance().outputVolume
        if session.isFinite, !session.isNaN {
            return max(0, min(1, session))
        }
        return volume
    }

    private func setBrightness(_ v: Double) {
        brightness = min(max(v, 0), 1)
        #if canImport(UIKit)
        hostScreen?.brightness = CGFloat(brightness)
        #endif
    }

    private func rateLabel(_ r: Float) -> String {
        if abs(r - 1) < 0.01 { return "1×" }
        if r == Float(Int(r)) { return "\(Int(r))×" }
        return String(format: "%.2g×", r)
    }

    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    @MainActor
    private func openExternal(_ option: ExternalPlayerOption) async {
        openingExternal = option
        let ok = await ExternalPlayerRouter.open(player: option, streamURL: url)
        openingExternal = nil
        if !ok {
            ExternalPlayerRouter.copyToPasteboard(url.absoluteString)
            errorText = String(format: localizer.t.filesPlayerOpenExternalFailed, option.displayName)
            showExternalFallback = true
        } else {
            dismiss()
        }
    }

    private func configureAudioSession() async {
        let mode: AVAudioSession.Mode = isAudio ? .default : .moviePlayback
        do {
            // setCategory/setActive on the main thread while a session is active
            // triggers SessionCore UI-unresponsiveness warnings — always hop off-main.
            try await Task.detached(priority: .userInitiated) {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: mode, options: [])
            }.value
            try await Self.activateAudioSession()
        } catch {
            AppLogger.shared.error("audio session: \(error.localizedDescription)", source: "OpenListPlayer")
        }
    }

    private static func activateAudioSession() async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                AVAudioSession.sharedInstance().activate(options: []) { activated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if activated {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "OpenListPlayer",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Audio session failed to activate"]
                            )
                        )
                    }
                }
            }
        } else {
            try await Task.detached(priority: .userInitiated) {
                try AVAudioSession.sharedInstance().setActive(true)
            }.value
        }
    }

    private static func deactivateAudioSession() async {
        if #available(iOS 27.0, *) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) { _, _ in
                    continuation.resume()
                }
            }
        } else {
            _ = try? await Task.detached(priority: .utility) {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }.value
        }
    }

    private func applyOrientation(landscape: Bool?, animated: Bool) {
        #if canImport(UIKit)
        let mask: UIInterfaceOrientationMask
        if landscape == true {
            mask = .landscape
        } else if landscape == false {
            mask = .portrait
        } else {
            mask = [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown]
        }
        OpenListOrientationLock.mask = mask
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            let apply = {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
                scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
            }
            if animated {
                // Coordinate layout with the system rotation animation.
                UIView.animate(
                    withDuration: 0.35,
                    delay: 0,
                    options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState]
                ) {
                    apply()
                    scene.windows.forEach { $0.layoutIfNeeded() }
                }
            } else {
                apply()
            }
        }
        #endif
    }
}

// MARK: - VLC engine

@MainActor
final class OpenListVLCEngine: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    let player: VLCMediaPlayer

    @Published private(set) var isReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var current: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var rate: Float = 1.0
    @Published private(set) var textTracks: [String] = []
    @Published private(set) var audioTracks: [String] = []
    /// nil = off / none selected.
    @Published private(set) var selectedTextTrackIndex: Int?
    @Published private(set) var selectedAudioTrackIndex: Int?
    @Published var failedMessage: String?

    private var pendingExternalSubtitleURL: URL?
    private var didAttachSubtitle = false
    private var subtitleRetryTask: Task<Void, Never>?

    override init() {
        // Network-friendly options for OpenList signed / remote streams.
        player = VLCMediaPlayer(options: [
            "--network-caching=1500",
            "--file-caching=1500",
            "--live-caching=1500",
            "--http-reconnect",
            "--avcodec-hw=any",
            "--sub-autodetect-file",
            // Prefer readable default scale; users can still toggle tracks.
            "--freetype-rel-fontsize=16"
        ])
        super.init()
        player.delegate = self
        player.timeChangeUpdateInterval = 0.5
        player.audio?.volume = 100
    }

    func play(url: URL, externalSubtitleURL: URL?) {
        failedMessage = nil
        isReady = false
        isPlaying = false
        current = 0
        duration = 0
        selectedTextTrackIndex = nil
        selectedAudioTrackIndex = nil
        didAttachSubtitle = false
        pendingExternalSubtitleURL = externalSubtitleURL
        subtitleRetryTask?.cancel()

        let media = VLCMedia(url: url)
        // Prefer software fallback path when hardware decode fails on odd streams.
        media?.addOption(":http-user-agent=Homelab/iOS")
        // Help common Chinese/UTF-8 SRT encodings; VLC falls back if mismatched.
        media?.addOption(":subsdec-encoding=UTF-8")
        if let externalSubtitleURL {
            // Best-effort pre-bind so the slave is ready when demux starts.
            media?.addOption(":sub-file=\(externalSubtitleURL.absoluteString)")
        }
        player.media = media
        player.play()

        if let externalSubtitleURL {
            scheduleSubtitleAttach(externalSubtitleURL)
        }
    }

    func stop() {
        subtitleRetryTask?.cancel()
        subtitleRetryTask = nil
        player.stop()
        player.drawable = nil
        isPlaying = false
        isReady = false
        pendingExternalSubtitleURL = nil
        didAttachSubtitle = false
    }

    func togglePlay() {
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = rate
            isPlaying = true
        }
    }

    func jump(by seconds: Double) {
        player.jump(withOffset: Int32(seconds * 1000))
    }

    func seek(toFraction fraction: Double) {
        let f = min(max(fraction, 0), 1)
        player.position = f
        if duration > 0 {
            current = duration * f
        }
    }

    func setRate(_ r: Float) {
        rate = r
        player.rate = r
    }

    func selectTextTrack(at index: Int) {
        let tracks = player.textTracks
        guard tracks.indices.contains(index) else { return }
        // Prefer exclusive selection via track object (more reliable than index alone).
        tracks[index].isSelectedExclusively = true
        selectedTextTrackIndex = index
        refreshTracks()
    }

    func deselectSubtitles() {
        player.deselectAllTextTracks()
        selectedTextTrackIndex = nil
        refreshTracks()
    }

    func selectAudioTrack(at index: Int) {
        let tracks = player.audioTracks
        guard tracks.indices.contains(index) else { return }
        tracks[index].isSelectedExclusively = true
        selectedAudioTrackIndex = index
        refreshTracks()
    }

    private func scheduleSubtitleAttach(_ url: URL) {
        subtitleRetryTask?.cancel()
        subtitleRetryTask = Task { @MainActor [weak self] in
            // Input must exist before addPlaybackSlave succeeds; retry a few times.
            for delayMs in [400, 900, 1600, 2800] as [UInt64] {
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                guard let self, !Task.isCancelled else { return }
                if self.didAttachSubtitle, !self.player.textTracks.isEmpty {
                    self.refreshTracks()
                    return
                }
                let result = self.player.addPlaybackSlave(url, type: .subtitle, enforce: true)
                if result == 0 {
                    self.didAttachSubtitle = true
                    // Give VLC a beat to register the track, then select it.
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    self.refreshTracks()
                    if let last = self.player.textTracks.indices.last {
                        self.selectTextTrack(at: last)
                    }
                    return
                }
            }
            self?.refreshTracks()
        }
    }

    private func refreshTracks() {
        let texts = player.textTracks
        let audios = player.audioTracks
        textTracks = texts.map { trackDisplayName($0) }
        audioTracks = audios.map { trackDisplayName($0) }
        selectedTextTrackIndex = texts.firstIndex(where: \.isSelected)
        selectedAudioTrackIndex = audios.firstIndex(where: \.isSelected)
    }

    private func trackDisplayName(_ track: VLCMediaPlayer.Track) -> String {
        let name = track.trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let id = track.trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? "Track" : id
    }

    // MARK: VLCMediaPlayerDelegate

    nonisolated func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        Task { @MainActor in
            switch newState {
            case .playing:
                self.isReady = true
                self.isPlaying = true
                self.refreshDuration()
                self.refreshTracks()
            case .paused:
                self.isPlaying = false
                self.isReady = true
            case .error:
                self.failedMessage = "Playback failed"
                self.isPlaying = false
            case .stopped, .stopping:
                self.isPlaying = false
            default:
                // Opening / buffering / unknown — keep spinner until .playing
                break
            }
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            let ms = Double(self.player.time.intValue)
            if ms.isFinite, ms >= 0 {
                self.current = ms / 1000.0
            }
            self.refreshDuration()
            self.isPlaying = self.player.isPlaying
            if self.player.isPlaying {
                self.isReady = true
            }
        }
    }

    nonisolated func mediaPlayerLengthChanged(_ length: Int64) {
        Task { @MainActor in
            if length > 0 {
                self.duration = Double(length) / 1000.0
            }
        }
    }

    nonisolated func mediaPlayerBufferingChanged(_ progress: Float) {
        Task { @MainActor in
            if progress >= 1.0, self.player.isPlaying {
                self.isReady = true
            }
        }
    }

    nonisolated func mediaPlayerTrackAdded(_ trackId: String, trackType: VLCMedia.TrackType) {
        Task { @MainActor in
            self.refreshTracks()
            // Auto-pick external text track once it appears.
            if trackType == .text,
               self.pendingExternalSubtitleURL != nil,
               self.selectedTextTrackIndex == nil,
               let last = self.player.textTracks.indices.last {
                self.selectTextTrack(at: last)
            }
        }
    }

    nonisolated func mediaPlayerTrackSelected(
        _ trackType: VLCMedia.TrackType,
        selectedId: String,
        unselectedId: String
    ) {
        Task { @MainActor in
            self.refreshTracks()
        }
    }

    private func refreshDuration() {
        if let media = player.media {
            let ms = media.length.intValue
            if ms > 0 {
                duration = Double(ms) / 1000.0
            }
        }
    }
}

// MARK: - Video host

/// UIView that VLC draws into via `drawable`.
struct OpenListVLCVideoView: UIViewRepresentable {
    let player: VLCMediaPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        // Defer drawable assignment until layout has a non-zero size.
        DispatchQueue.main.async {
            player.drawable = view
            player.videoFitMode = .smaller
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if player.drawable as? UIView !== uiView {
            player.drawable = uiView
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Caller owns player lifecycle; clear drawable only if still bound here.
        _ = uiView
    }
}

// MARK: - Orientation lock

enum OpenListOrientationLock {
    nonisolated(unsafe) static var mask: UIInterfaceOrientationMask = [
        .portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown
    ]
}

// MARK: - System volume (MPVolumeView)

@MainActor
final class OpenListSystemVolumeWriter {
    var isAdjusting = false
    var onExternalChange: ((Float) -> Void)?

    private var slider: UISlider?
    private var observation: NSKeyValueObservation?

    func attach(slider: UISlider) {
        self.slider = slider
    }

    func setVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        // Force-find slider if attach hasn't finished yet.
        if slider == nil {
            // no-op; attach happens async from MPVolumeView
        }
        slider?.value = clamped
        // Also nudge KVO consumers so UI volume badge tracks system immediately.
        if !isAdjusting {
            onExternalChange?(clamped)
        }
    }

    func startObserving() {
        observation?.invalidate()
        // Observe on main; AVAudioSession delivers KVO there for outputVolume.
        observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new, .initial]) { [weak self] _, change in
            Task { @MainActor in
                guard let self, !self.isAdjusting, let v = change.newValue else { return }
                self.onExternalChange?(v)
            }
        }
    }

    deinit {
        observation?.invalidate()
    }
}

private struct OpenListSystemVolumeView: UIViewRepresentable {
    let writer: OpenListSystemVolumeWriter

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 120, height: 40))
        // Keep interactive for system volume writes; park off-screen so it never covers UI.
        view.clipsToBounds = true
        DispatchQueue.main.async {
            Self.attachSlider(from: view, to: writer)
        }
        // Retry once after layout (slider sometimes mounts late).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Self.attachSlider(from: view, to: writer)
        }
        return view
    }

    private static func attachSlider(from root: UIView, to writer: OpenListSystemVolumeWriter) {
        func findSlider(_ v: UIView) -> UISlider? {
            if let s = v as? UISlider { return s }
            for c in v.subviews {
                if let s = findSlider(c) { return s }
            }
            return nil
        }
        if let slider = findSlider(root) {
            writer.attach(slider: slider)
        }
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// MARK: - Host screen

private struct OpenListHostScreenReader: UIViewRepresentable {
    let onScreen: (UIScreen) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let screen = uiView.window?.windowScene?.screen {
                onScreen(screen)
            }
        }
    }
}
