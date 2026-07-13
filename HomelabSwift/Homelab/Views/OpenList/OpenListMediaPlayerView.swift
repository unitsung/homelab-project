import AVFoundation
import AVKit
import MediaPlayer
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

/// Full-screen player: auto-plays on open.
/// Tap center → show/hide chrome (auto-hide after a few seconds).
/// Bottom: progress · transport · rate · subtitles · audio track · landscape · import local sub.
/// Sides: left brightness / right volume vertical drag.
struct OpenListMediaPlayerView: View {
    let url: URL
    let title: String
    let isAudio: Bool
    /// Optional external subtitle stream (OpenList /p or /d for .srt/.vtt).
    var externalSubtitleURL: URL? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var isPlaying = false
    @State private var duration: Double = 0
    @State private var current: Double = 0
    /// Tracks **system** output volume (0…1), not AVPlayer relative gain.
    @State private var volume: Float = AVAudioSession.sharedInstance().outputVolume
    @State private var brightness: Double = 0.5
    @State private var showControls = true
    @State private var errorText: String?
    @State private var timeObserver: Any?
    @State private var timeObserverPlayer: AVPlayer?
    @State private var hideTask: Task<Void, Never>?
    @State private var rate: Float = 1.0
    @State private var statusObservation: NSKeyValueObservation?
    @State private var isLandscapePreferred = true
    @State private var sideHud: SideHUD?
    @State private var dragStartValue: Double = 0
    @State private var showLocalSubtitlePicker = false
    /// True when format is MKV/AVI/etc. or AVPlayer reports unplayable — offer external apps.
    @State private var showExternalFallback = false
    @State private var openingExternal: ExternalPlayerOption?
    /// Screen resolved from the hosting window (iOS 26: do not use UIScreen.main).
    @State private var hostScreen: UIScreen?
    /// Hidden `MPVolumeView` host used to write system volume + mirror hardware buttons.
    @State private var systemVolumeWriter = OpenListSystemVolumeWriter()

    // Embedded subtitle tracks
    @State private var subtitleGroup: AVMediaSelectionGroup?
    @State private var embeddedSubtitles: [AVMediaSelectionOption] = []
    @State private var selectedEmbedded: AVMediaSelectionOption?

    // Audio tracks
    @State private var audioGroup: AVMediaSelectionGroup?
    @State private var audioTracks: [AVMediaSelectionOption] = []
    @State private var selectedAudio: AVMediaSelectionOption?

    // External SRT/VTT overlay (server sibling or local file)
    @State private var externalCues: [SubtitleCue] = []
    @State private var useExternalSubtitles = false
    @State private var currentCueText: String = ""
    @State private var externalSubtitleName: String = ""

    private let rateOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

    /// Containers Apple AVPlayer typically cannot decode (needs VLC / Infuse / SenPlayer).
    private static let avPlayerUnfriendlyExtensions: Set<String> = [
        "mkv", "avi", "wmv", "flv", "rmvb", "rm", "asf", "divx", "xvid", "ogm", "mpg", "mpeg"
    ]

    private static let observerQueue = DispatchQueue(
        label: "com.homelab.openlist.player.observer",
        qos: .userInitiated
    )

    private enum SideHUD: Equatable {
        case brightness(Double)
        case volume(Double)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Resolve UIScreen from view.window (iOS 26-safe; never UIScreen.main).
                OpenListHostScreenReader { screen in
                    if hostScreen !== screen {
                        hostScreen = screen
                        brightness = Double(screen.brightness)
                    }
                }
                .frame(width: 0, height: 0)

                // Must stay in hierarchy so MPVolumeView can drive system volume.
                OpenListSystemVolumeView(writer: systemVolumeWriter)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)

                if let errorText {
                    errorBlock(errorText)
                } else {
                    videoSurface
                    sideGestureLayers(size: geo.size)

                    if useExternalSubtitles, !currentCueText.isEmpty {
                        VStack {
                            Spacer()
                            Text(currentCueText)
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .padding(.horizontal, 24)
                                .padding(.bottom, showControls ? 150 : 40)
                        }
                        .allowsHitTesting(false)
                    }

                    if showControls {
                        controlsOverlay
                            .transition(.opacity)
                    }
                    if let sideHud {
                        sideHudBadge(sideHud)
                    }
                    if !isReady {
                        ProgressView().tint(.white).scaleEffect(1.1)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task { await setup() }
        .onAppear {
            if !isAudio {
                isLandscapePreferred = true
                applyOrientation(landscape: true)
            } else {
                isLandscapePreferred = false
                applyOrientation(landscape: false)
            }
        }
        .onDisappear {
            teardown()
            applyOrientation(landscape: nil)
        }
        .fileImporter(
            isPresented: $showLocalSubtitlePicker,
            allowedContentTypes: [
                .plainText,
                UTType(filenameExtension: "srt") ?? .data,
                UTType(filenameExtension: "vtt") ?? .data,
                UTType(filenameExtension: "ass") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleLocalSubtitleImport(result) }
        }
    }

    // MARK: - Surfaces

    @ViewBuilder
    private var videoSurface: some View {
        if isAudio {
            audioBackdrop
        } else if let player {
            OpenListAVPlayerLayerView(player: player)
                .ignoresSafeArea()
        }
    }

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
                Text("MKV / AVI 等格式系统内置解码不支持，请用专业播放器打开")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 8) {
                    ForEach([ExternalPlayerOption.senPlayer, .vlc, .infuse, .nPlayer, .system], id: \.id) { option in
                        Button {
                            Task { await openExternal(option) }
                        } label: {
                            HStack {
                                Image(systemName: option.systemImage)
                                Text(option.displayName)
                                    .fontWeight(.semibold)
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
                .padding(.top, 4)
            }

            Button { dismiss() } label: {
                Text("关闭")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }

    @MainActor
    private func openExternal(_ option: ExternalPlayerOption) async {
        openingExternal = option
        let ok = await ExternalPlayerRouter.open(player: option, streamURL: url)
        openingExternal = nil
        if !ok {
            ExternalPlayerRouter.copyToPasteboard(url.absoluteString)
            errorText = "无法打开 \(option.displayName)，链接已复制"
            showExternalFallback = true
        } else {
            dismiss()
        }
    }

    // MARK: - Gestures (Infuse-style zones)

    private func sideGestureLayers(size: CGSize) -> some View {
        HStack(spacing: 0) {
            // Left third: brightness vertical · double-tap seek -10
            Color.clear
                .contentShape(Rectangle())
                .gesture(verticalDrag(kind: .brightness, height: size.height))
                .onTapGesture(count: 2) { seek(by: -10) }
                .onTapGesture(count: 1) { handleCenterTap() }

            // Center third: toggle chrome
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { handleCenterTap() }

            // Right third: volume vertical · double-tap seek +10
            Color.clear
                .contentShape(Rectangle())
                .gesture(verticalDrag(kind: .volume, height: size.height))
                .onTapGesture(count: 2) { seek(by: 10) }
                .onTapGesture(count: 1) { handleCenterTap() }
        }
        .ignoresSafeArea()
    }

    private enum DragKind { case brightness, volume }

    private func verticalDrag(kind: DragKind, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if abs(value.translation.height) < abs(value.translation.width) * 1.2 { return }
                // ~40% of view height spans full 0…1 so upper/lower limits are reachable.
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
                // Snap HUD to the real system volume after the write settles.
                volume = currentSystemVolume()
                withAnimation(.easeOut(duration: 0.3)) { sideHud = nil }
            }
    }

    /// Infuse-like edge pill (left = brightness, right = volume)
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
            if v < 0.01 {
                icon = "speaker.slash.fill"
            } else if v < 0.34 {
                icon = "speaker.wave.1.fill"
            } else if v < 0.67 {
                icon = "speaker.wave.2.fill"
            } else {
                icon = "speaker.wave.3.fill"
            }
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
            // Vertical bar
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

    // MARK: - Controls (VLC / Infuse layout)

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            infuseTopBar
            Spacer()
            // Center play when paused (Infuse)
            if !isPlaying, isReady {
                Button { togglePlay() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            infuseBottomBar
        }
    }

    private var infuseTopBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !isAudio {
                    Text(clock(current) + "  ·  " + clock(duration))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.65), .black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var infuseBottomBar: some View {
        VStack(spacing: 14) {
            // Progress: current ——●—— remaining  (Infuse/VLC)
            HStack(spacing: 10) {
                Text(clock(current))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 48, alignment: .leading)

                if duration.isFinite, duration > 0, !duration.isNaN {
                    Slider(
                        value: Binding(
                            get: { safe(current, upper: duration) },
                            set: { seek(to: $0) }
                        ),
                        in: 0...duration
                    )
                    .tint(.white)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                }

                Text(clock(max(0, duration - current)))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 48, alignment: .trailing)
            }

            // Transport
            HStack(spacing: 0) {
                Spacer()
                Button { seek(by: -10) } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 44)
                }
                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 44)
                }
                Button { seek(by: 10) } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 44)
                }
                Spacer()
            }
            .buttonStyle(.plain)

            // Icon tool strip (Infuse-style)
            HStack(spacing: 0) {
                rateMenuButton
                if !isAudio {
                    subtitleMenuButton
                    audioTrackMenuButton
                    landscapeButton
                    Button {
                        showLocalSubtitlePicker = true
                        scheduleHide()
                    } label: {
                        toolIcon("doc.badge.plus", label: "Sub+")
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Tool menus (icon column)

    private var rateMenuButton: some View {
        Menu {
            ForEach(rateOptions, id: \.self) { r in
                Button {
                    setRate(r)
                } label: {
                    if abs(rate - r) < 0.01 {
                        Label(rateLabel(r), systemImage: "checkmark")
                    } else {
                        Text(rateLabel(r))
                    }
                }
            }
        } label: {
            toolIcon(nil, label: rateLabel(rate), textOnly: true)
        }
    }

    private var subtitleMenuButton: some View {
        Menu {
            Button {
                selectEmbedded(nil)
                useExternalSubtitles = false
                currentCueText = ""
            } label: {
                if selectedEmbedded == nil, !useExternalSubtitles {
                    Label("Off", systemImage: "checkmark")
                } else {
                    Text("Off")
                }
            }
            if !embeddedSubtitles.isEmpty {
                Section("Embedded") {
                    ForEach(Array(embeddedSubtitles.enumerated()), id: \.offset) { _, opt in
                        Button {
                            useExternalSubtitles = false
                            currentCueText = ""
                            selectEmbedded(opt)
                        } label: {
                            if selectedEmbedded == opt, !useExternalSubtitles {
                                Label(opt.displayName, systemImage: "checkmark")
                            } else {
                                Text(opt.displayName)
                            }
                        }
                    }
                }
            }
            if !externalCues.isEmpty {
                Section("External") {
                    Button {
                        selectEmbedded(nil)
                        useExternalSubtitles = true
                        refreshCue()
                    } label: {
                        let name = externalSubtitleName.isEmpty ? "External" : externalSubtitleName
                        if useExternalSubtitles {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            }
            Button {
                showLocalSubtitlePicker = true
            } label: {
                Label("Import…", systemImage: "folder")
            }
        } label: {
            toolIcon(
                "captions.bubble",
                label: "CC",
                active: selectedEmbedded != nil || useExternalSubtitles
            )
        }
    }

    private var audioTrackMenuButton: some View {
        Menu {
            if audioTracks.isEmpty {
                Text("Default")
            } else {
                ForEach(Array(audioTracks.enumerated()), id: \.offset) { _, opt in
                    Button {
                        selectAudio(opt)
                    } label: {
                        if selectedAudio == opt {
                            Label(opt.displayName, systemImage: "checkmark")
                        } else {
                            Text(opt.displayName)
                        }
                    }
                }
            }
        } label: {
            toolIcon("waveform", label: "Audio", active: audioTracks.count > 1)
        }
        .disabled(audioTracks.isEmpty)
        .opacity(audioTracks.isEmpty ? 0.4 : 1)
    }

    private var landscapeButton: some View {
        Button {
            isLandscapePreferred.toggle()
            applyOrientation(landscape: isLandscapePreferred)
            scheduleHide()
        } label: {
            toolIcon(
                isLandscapePreferred ? "rectangle.portrait.rotate" : "rectangle.landscape.rotate",
                label: isLandscapePreferred ? "Portrait" : "Landscape"
            )
        }
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
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 22)
            }
            if !textOnly {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("Speed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Lifecycle

    @MainActor
    private func setup() async {
        teardownKeepOrientation()
        errorText = nil
        showExternalFallback = false
        showControls = true
        isReady = false
        isPlaying = false

        AppLogger.shared.info("play setup url=\(url.absoluteString) audio=\(isAudio)", source: "OpenListPlayer")

        await configureAudioSession()
        volume = currentSystemVolume()
        systemVolumeWriter.onExternalChange = { newValue in
            volume = newValue
        }
        systemVolumeWriter.startObserving()

        let fileExt = (title as NSString).pathExtension.lowercased()
        let unfriendly = Self.avPlayerUnfriendlyExtensions.contains(fileExt)
            || Self.avPlayerUnfriendlyExtensions.contains(url.pathExtension.lowercased())

        // Load external SRT/VTT in parallel (does not block autoplay).
        if let externalSubtitleURL, !isAudio {
            Task { await loadExternalSubtitles(from: externalSubtitleURL) }
        }

        // MKV etc.: AVPlayer cannot decode — skip long timeout and offer Infuse/VLC immediately.
        // Still attempt play for edge cases (some remuxed streams may work).
        let asset = AVURLAsset(url: url)
        var playable = true
        do {
            playable = try await asset.load(.isPlayable)
        } catch {
            playable = !unfriendly
        }
        if Task.isCancelled { return }

        if unfriendly, !playable {
            presentExternalFormatFallback(extensionName: fileExt.isEmpty ? "mkv" : fileExt)
            return
        }

        let item = AVPlayerItem(asset: asset)
        let av = AVPlayer(playerItem: item)
        // Full system volume range: keep player gain at 1 and drive MPVolumeView instead.
        av.volume = 1.0
        av.automaticallyWaitsToMinimizeStalling = true
        player = av

        let ready = await waitUntilReady(item: item, timeout: unfriendly ? 12 : 30)
        guard !Task.isCancelled, player === av else { return }

        switch ready {
        case .ready:
            let d = item.duration.seconds
            if d.isFinite, !d.isNaN, d > 0 { duration = d }
            isReady = true
            await loadMediaTracks(from: item)
            // Auto-play immediately (page 2)
            attachObserver(to: av)
            av.play()
            av.rate = rate
            isPlaying = true
            showControls = true
            scheduleHide()
        case .failed(let message):
            AppLogger.shared.error("play failed: \(message)", source: "OpenListPlayer")
            if unfriendly || Self.looksLikeCodecError(message) {
                presentExternalFormatFallback(extensionName: fileExt.isEmpty ? "video" : fileExt, detail: message)
            } else {
                errorText = message
                showExternalFallback = true
            }
        case .timeout:
            if unfriendly {
                presentExternalFormatFallback(extensionName: fileExt.isEmpty ? "mkv" : fileExt)
            } else {
                isReady = true
                await loadMediaTracks(from: item)
                attachObserver(to: av)
                av.play()
                av.rate = rate
                isPlaying = true
                showControls = true
                scheduleHide()
            }
        case .cancelled:
            return
        }
    }

    private func presentExternalFormatFallback(extensionName: String, detail: String? = nil) {
        showExternalFallback = true
        let ext = extensionName.uppercased()
        if let detail, !detail.isEmpty {
            errorText = "无法播放 \(ext)\n\(detail)"
        } else {
            errorText = "无法播放 \(ext) 格式"
        }
        isReady = false
        player?.pause()
        player = nil
    }

    private static func looksLikeCodecError(_ message: String) -> Bool {
        let m = message.lowercased()
        return m.contains("format") || m.contains("codec") || m.contains("decode")
            || m.contains("not supported") || m.contains("无法") || m.contains("不支持")
            || m.contains("error") || m.contains("failed")
    }

    private func loadMediaTracks(from item: AVPlayerItem) async {
        let asset = item.asset
        do {
            if let group = try await asset.loadMediaSelectionGroup(for: .legible) {
                subtitleGroup = group
                embeddedSubtitles = group.options
                selectedEmbedded = item.currentMediaSelection.selectedMediaOption(in: group)
            } else {
                subtitleGroup = nil
                embeddedSubtitles = []
                selectedEmbedded = nil
            }
        } catch {
            subtitleGroup = nil
            embeddedSubtitles = []
            selectedEmbedded = nil
        }
        do {
            if let group = try await asset.loadMediaSelectionGroup(for: .audible) {
                audioGroup = group
                audioTracks = group.options
                selectedAudio = item.currentMediaSelection.selectedMediaOption(in: group)
            } else {
                audioGroup = nil
                audioTracks = []
                selectedAudio = nil
            }
        } catch {
            audioGroup = nil
            audioTracks = []
            selectedAudio = nil
        }
    }

    private func selectEmbedded(_ option: AVMediaSelectionOption?) {
        guard let player, let item = player.currentItem, let group = subtitleGroup else {
            selectedEmbedded = option
            return
        }
        item.select(option, in: group)
        selectedEmbedded = option
        scheduleHide()
    }

    private func selectAudio(_ option: AVMediaSelectionOption) {
        guard let player, let item = player.currentItem, let group = audioGroup else {
            selectedAudio = option
            return
        }
        item.select(option, in: group)
        selectedAudio = option
        scheduleHide()
    }

    private func loadExternalSubtitles(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            applySubtitleData(data, name: url.lastPathComponent)
        } catch {
            AppLogger.shared.error("external subs failed: \(error.localizedDescription)", source: "OpenListPlayer")
        }
    }

    @MainActor
    private func handleLocalSubtitleImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .failure(let error):
            AppLogger.shared.error("local sub pick failed: \(error.localizedDescription)", source: "OpenListPlayer")
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: fileURL)
                applySubtitleData(data, name: fileURL.lastPathComponent)
            } catch {
                AppLogger.shared.error("local sub read failed: \(error.localizedDescription)", source: "OpenListPlayer")
            }
        }
        scheduleHide()
    }

    @MainActor
    private func applySubtitleData(_ data: Data, name: String) {
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else { return }
        let lower = name.lowercased()
        let cues: [SubtitleCue]
        if lower.hasSuffix(".vtt") {
            cues = SubtitleCue.parseVTT(text)
        } else if lower.hasSuffix(".ass") || lower.hasSuffix(".ssa") {
            // Best-effort: strip dialogue lines as plain text cues (rough)
            cues = SubtitleCue.parseASS(text)
        } else {
            cues = SubtitleCue.parseSRT(text)
        }
        externalCues = cues
        externalSubtitleName = name
        if !cues.isEmpty {
            selectEmbedded(nil)
            useExternalSubtitles = true
            refreshCue()
        }
        AppLogger.shared.info("subs applied \(name) cues=\(cues.count)", source: "OpenListPlayer")
    }

    private enum ReadyResult: Sendable {
        case ready
        case failed(String)
        case timeout
        case cancelled
    }

    private func waitUntilReady(item: AVPlayerItem, timeout: TimeInterval) async -> ReadyResult {
        if item.status == .readyToPlay { return .ready }
        if item.status == .failed {
            return .failed(item.error?.localizedDescription ?? "Playback failed")
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<ReadyResult, Never>) in
                final class Once: @unchecked Sendable {
                    private let lock = NSLock()
                    private var done = false
                    private let cont: CheckedContinuation<ReadyResult, Never>
                    var observation: NSKeyValueObservation?
                    init(_ cont: CheckedContinuation<ReadyResult, Never>) { self.cont = cont }
                    func finish(_ result: ReadyResult) {
                        lock.lock()
                        defer { lock.unlock() }
                        guard !done else { return }
                        done = true
                        observation?.invalidate()
                        observation = nil
                        cont.resume(returning: result)
                    }
                }
                let once = Once(continuation)
                once.observation = item.observe(\.status, options: [.initial, .new]) { observed, _ in
                    switch observed.status {
                    case .readyToPlay: once.finish(.ready)
                    case .failed: once.finish(.failed(observed.error?.localizedDescription ?? "Playback failed"))
                    default: break
                    }
                }
                Task { @MainActor in self.statusObservation = once.observation }
                Self.observerQueue.asyncAfter(deadline: .now() + timeout) { once.finish(.timeout) }
            }
        } onCancel: {
            Task { @MainActor in
                statusObservation?.invalidate()
                statusObservation = nil
            }
        }
    }

    private func attachObserver(to av: AVPlayer) {
        removeTimeObserverIfNeeded()
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        // userInitiated queue + async MainActor hop avoids UI QoS waiting on Default AV work.
        let token = av.addPeriodicTimeObserver(forInterval: interval, queue: Self.observerQueue) { [weak av] time in
            guard let av else { return }
            let seconds = time.seconds
            let durationSeconds = av.currentItem?.duration.seconds ?? .nan
            let playing = av.rate > 0
            Task { @MainActor [weak av] in
                guard av != nil else { return }
                if seconds.isFinite, !seconds.isNaN { current = max(0, seconds) }
                if durationSeconds.isFinite, !durationSeconds.isNaN, durationSeconds > 0 {
                    duration = durationSeconds
                }
                isPlaying = playing
                refreshCue()
            }
        }
        timeObserver = token
        timeObserverPlayer = av
    }

    private func refreshCue() {
        guard useExternalSubtitles, !externalCues.isEmpty else {
            if useExternalSubtitles { currentCueText = "" }
            return
        }
        currentCueText = externalCues.first(where: { current >= $0.start && current <= $0.end })?.text ?? ""
    }

    private func removeTimeObserverIfNeeded() {
        if let token = timeObserver, let owner = timeObserverPlayer {
            owner.removeTimeObserver(token)
        }
        timeObserver = nil
        timeObserverPlayer = nil
    }

    private func teardownKeepOrientation() {
        hideTask?.cancel()
        hideTask = nil
        statusObservation?.invalidate()
        statusObservation = nil
        systemVolumeWriter.stopObserving()
        systemVolumeWriter.onExternalChange = nil
        systemVolumeWriter.isAdjusting = false
        removeTimeObserverIfNeeded()
        player?.pause()
        player = nil
        isPlaying = false
        isReady = false
        embeddedSubtitles = []
        selectedEmbedded = nil
        subtitleGroup = nil
        audioGroup = nil
        audioTracks = []
        selectedAudio = nil
        externalCues = []
        useExternalSubtitles = false
        currentCueText = ""
        externalSubtitleName = ""
    }

    private func teardown() {
        teardownKeepOrientation()
        // Deactivate off the main path — sync setActive can hitch the UI.
        Task { await Self.deactivateAudioSession() }
    }

    // MARK: - Actions

    private func handleCenterTap() {
        guard errorText == nil else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            showControls.toggle()
        }
        if showControls { scheduleHide() }
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            showControls = true
        } else {
            player.play()
            player.rate = rate
            isPlaying = true
            scheduleHide()
        }
    }

    private func seek(to seconds: Double) {
        guard let player else { return }
        let t = safe(seconds, upper: duration > 0 ? duration : max(seconds, 0))
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600))
        current = t
        refreshCue()
        scheduleHide()
    }

    private func seek(by delta: Double) {
        seek(to: current + delta)
    }

    private func setVolume(_ v: Float) {
        let clamped = max(0, min(1, v))
        volume = clamped
        // Keep AVPlayer at full gain so the system slider is the real loudness control.
        player?.volume = 1.0
        systemVolumeWriter.setVolume(clamped)
    }

    private func currentSystemVolume() -> Float {
        let session = AVAudioSession.sharedInstance().outputVolume
        if session.isFinite, !session.isNaN {
            return max(0, min(1, session))
        }
        return volume
    }

    private func configureAudioSession() async {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: isAudio ? .default : .moviePlayback, options: [])
            try await Self.activateAudioSession()
        } catch {
            AppLogger.shared.error("audio session: \(error.localizedDescription)", source: "OpenListPlayer")
        }
    }

    /// Activates the shared session without blocking the main thread.
    private static func activateAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.activate(options: []) { activated, error in
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
            // iOS 26: keep sync setActive, but never on the main thread.
            try await Task.detached(priority: .userInitiated) {
                try AVAudioSession.sharedInstance().setActive(true)
            }.value
        }
    }

    /// Deactivates the shared session without blocking the main thread.
    private static func deactivateAudioSession() async {
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 27.0, *) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                session.deactivate(options: .notifyOthersOnDeactivation) { _, error in
                    if let error {
                        AppLogger.shared.error(
                            "audio session deactivate: \(error.localizedDescription)",
                            source: "OpenListPlayer"
                        )
                    }
                    continuation.resume()
                }
            }
        } else {
            do {
                try await Task.detached(priority: .utility) {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }.value
            } catch {
                AppLogger.shared.error(
                    "audio session deactivate: \(error.localizedDescription)",
                    source: "OpenListPlayer"
                )
            }
        }
    }

    private func setBrightness(_ v: Double) {
        brightness = min(max(v, 0), 1)
        #if canImport(UIKit)
        hostScreen?.brightness = CGFloat(brightness)
        #endif
    }

    private func setRate(_ r: Float) {
        rate = r
        if isPlaying { player?.rate = r }
        scheduleHide()
    }

    private func rateLabel(_ r: Float) -> String {
        if abs(r - 1) < 0.01 { return "1×" }
        if r == Float(Int(r)) { return "\(Int(r))×" }
        return String(format: "%.2g×", r)
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard isPlaying, showControls else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled, isPlaying {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
    }

    private func safe(_ value: Double, upper: Double) -> Double {
        guard value.isFinite, !value.isNaN else { return 0 }
        guard upper.isFinite, !upper.isNaN, upper > 0 else { return max(0, value) }
        return min(max(0, value), upper)
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

    private func applyOrientation(landscape: Bool?) {
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
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if #available(iOS 16.0, *) {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
                scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
            } else {
                let orient: UIInterfaceOrientation = (landscape == false) ? .portrait : .landscapeRight
                UIDevice.current.setValue(orient.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }
        #endif
    }
}

// MARK: - Subtitle cues (SRT / VTT)

struct SubtitleCue: Sendable {
    let start: Double
    let end: Double
    let text: String

    static func parseSRT(_ raw: String) -> [SubtitleCue] {
        let blocks = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []
        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard lines.count >= 2 else { continue }
            let timeLine = lines.first(where: { $0.contains("-->") }) ?? ""
            guard let range = parseTimeRange(timeLine, srt: true) else { continue }
            let textLines = lines.drop(while: { !$0.contains("-->") }).dropFirst()
            let text = textLines
                .map { $0.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                cues.append(SubtitleCue(start: range.0, end: range.1, text: text))
            }
        }
        return cues
    }

    static func parseVTT(_ raw: String) -> [SubtitleCue] {
        let body = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = body.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []
        for block in blocks {
            if block.hasPrefix("WEBVTT") { continue }
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard let timeLine = lines.first(where: { $0.contains("-->") }) else { continue }
            guard let range = parseTimeRange(timeLine, srt: false) else { continue }
            let textLines = lines.drop(while: { !$0.contains("-->") }).dropFirst()
            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                cues.append(SubtitleCue(start: range.0, end: range.1, text: text))
            }
        }
        return cues
    }

    /// Rough ASS/SSA: Dialogue lines → simple timed cues (style ignored).
    static func parseASS(_ raw: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for line in lines where line.hasPrefix("Dialogue:") {
            // Dialogue: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
            let body = String(line.dropFirst("Dialogue:".count)).trimmingCharacters(in: .whitespaces)
            let parts = body.split(separator: ",", maxSplits: 9, omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 10 else { continue }
            guard let start = parseASSTime(parts[1]), let end = parseASSTime(parts[2]) else { continue }
            var text = parts[9]
                .replacingOccurrences(of: "\\N", with: "\n")
                .replacingOccurrences(of: "\\n", with: "\n")
            text = text.replacingOccurrences(of: "\\{[^}]*\\}", with: "", options: .regularExpression)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                cues.append(SubtitleCue(start: start, end: end, text: text))
            }
        }
        return cues
    }

    private static func parseASSTime(_ raw: String) -> Double? {
        // H:MM:SS.cs
        let bits = raw.trimmingCharacters(in: .whitespaces).split(separator: ":").map(String.init)
        guard bits.count == 3,
              let h = Double(bits[0]),
              let m = Double(bits[1]),
              let s = Double(bits[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }

    private static func parseTimeRange(_ line: String, srt: Bool) -> (Double, Double)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count >= 2 else { return nil }
        let startRaw = parts[0].trimmingCharacters(in: .whitespaces)
        let endRaw = parts[1].split(separator: " ").first.map(String.init) ?? parts[1]
        guard let s = parseTimestamp(startRaw, srt: srt),
              let e = parseTimestamp(endRaw.trimmingCharacters(in: .whitespaces), srt: srt) else { return nil }
        return (s, e)
    }

    private static func parseTimestamp(_ raw: String, srt: Bool) -> Double? {
        // 00:00:01,000 or 00:00:01.000 or 00:01.000
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
        let bits = cleaned.split(separator: ":").map(String.init)
        guard bits.count == 2 || bits.count == 3 else { return nil }
        if bits.count == 2 {
            guard let m = Double(bits[0]), let s = Double(bits[1]) else { return nil }
            return m * 60 + s
        }
        guard let h = Double(bits[0]), let m = Double(bits[1]), let s = Double(bits[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }
}

// MARK: - Orientation lock

@MainActor
enum OpenListOrientationLock {
    static var mask: UIInterfaceOrientationMask = [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown]
}

// MARK: - System volume (MPVolumeView)

/// Holds a reference to the slider inside a hidden `MPVolumeView` so gestures can write system volume.
@MainActor
final class OpenListSystemVolumeWriter {
    weak var slider: UISlider?
    /// True while the in-player vertical drag is writing volume (ignore echo from KVO).
    var isAdjusting = false
    /// Fired on the main actor when hardware buttons (or other apps) change output volume.
    var onExternalChange: ((Float) -> Void)?

    private var observation: NSKeyValueObservation?

    func setVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        guard let slider else { return }
        // Only write when changed to reduce system volume HUD spam / work.
        if abs(slider.value - clamped) < 0.001 { return }
        slider.value = clamped
    }

    func startObserving() {
        observation?.invalidate()
        observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let next = change.newValue else { return }
            Task { @MainActor in
                guard let self, !self.isAdjusting else { return }
                self.onExternalChange?(max(0, min(1, next)))
            }
        }
    }

    func stopObserving() {
        observation?.invalidate()
        observation = nil
    }
}

/// Embeds a zero-size `MPVolumeView` so we can drive the system volume slider.
private struct OpenListSystemVolumeView: UIViewRepresentable {
    let writer: OpenListSystemVolumeWriter

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.showsVolumeSlider = true
        view.alpha = 0.01
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            self.bindSlider(in: view, attempt: 0)
        }
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        if writer.slider == nil {
            DispatchQueue.main.async {
                self.bindSlider(in: uiView, attempt: 0)
            }
        }
    }

    private func bindSlider(in volumeView: MPVolumeView, attempt: Int) {
        if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
            writer.slider = slider
            return
        }
        // Slider is created lazily after the volume view is in a window.
        guard attempt < 12 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.bindSlider(in: volumeView, attempt: attempt + 1)
        }
    }
}

// MARK: - Layer host

#if canImport(UIKit)
/// Reads `view.window?.windowScene?.screen` — never `UIScreen.main` (deprecated iOS 26).
private struct OpenListHostScreenReader: UIViewRepresentable {
    let onResolve: (UIScreen) -> Void

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.onResolve = onResolve
        return view
    }

    func updateUIView(_ uiView: HostView, context: Context) {
        uiView.onResolve = onResolve
        uiView.publishIfPossible()
    }

    final class HostView: UIView {
        var onResolve: ((UIScreen) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            publishIfPossible()
        }

        func publishIfPossible() {
            guard let screen = window?.windowScene?.screen else { return }
            onResolve?(screen)
        }
    }
}

struct OpenListAVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        view.attach(player: player)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.attach(player: player)
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private weak var boundPlayer: AVPlayer?

        func attach(player: AVPlayer) {
            guard boundPlayer !== player else { return }
            boundPlayer = player
            // Defer off the interactive frame to reduce QoS inversion with AVFoundation.
            Task { @MainActor [weak self] in
                guard let self, self.boundPlayer === player else { return }
                self.playerLayer.player = player
            }
        }
    }
}
#else
private struct OpenListHostScreenReader: View {
    let onResolve: (Any) -> Void
    var body: some View { EmptyView() }
}

struct OpenListAVPlayerLayerView: View {
    let player: AVPlayer
    var body: some View { VideoPlayer(player: player) }
}
#endif
