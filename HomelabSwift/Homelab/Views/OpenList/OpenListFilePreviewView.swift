import AVKit
import PDFKit
import SwiftUI
import WebKit

/// In-app preview: media (full chrome), image zoom, text/md/html edit, pdf, download.
struct OpenListFilePreviewView: View {
    let item: FileItem
    let detail: FileDetail?
    let isLoading: Bool
    let errorMessage: String?
    let client: OpenListAPIClient?
    let loadTextContent: (() async throws -> String)?
    let onPlayBuiltIn: () -> Void
    /// Open a specific external player (icon grid). No nested sheet required.
    let onOpenExternalPlayer: (ExternalPlayerOption) -> Void
    let onDownload: () -> Void
    let onCopyLink: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    let onSaved: () -> Void

    @Environment(Localizer.self) private var localizer
    @State private var textBody: String?
    @State private var textError: String?
    @State private var textLoading = false
    @State private var showMarkdownRendered = true
    @State private var isEditing = false
    @State private var editBuffer = ""
    @State private var isSaving = false
    @State private var imageScale: CGFloat = 1

    private var kind: FilePreviewKind { item.previewKind }
    private var streamURL: URL? { detail?.playURL ?? detail?.contentURL }
    private var serviceColor: Color { ServiceType.openlist.colors.primary }

    private var previewTaskKey: String {
        if isLoading || detail == nil {
            return "wait:\(item.path)"
        }
        return "go:\(item.path)"
    }

    private var kindDisplayName: String {
        switch kind {
        case .video: return localizer.t.filesKindVideo
        case .audio: return localizer.t.filesKindAudio
        case .image: return localizer.t.filesKindImage
        case .markdown: return localizer.t.filesKindMarkdown
        case .html: return localizer.t.filesKindHTML
        case .text: return localizer.t.filesKindText
        case .pdf: return localizer.t.filesKindPDF
        case .download, .none: return localizer.t.filesKindFile
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && detail == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, detail == nil {
                    ContentUnavailableView(
                        localizer.t.filesPreviewFailed,
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    contentScroll
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.close, action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if kind == .video || kind == .audio {
                            Button(action: onPlayBuiltIn) {
                                Label(localizer.t.filesPlay, systemImage: "play.fill")
                            }
                        }
                        if item.isEditableText, !isEditing {
                            Button {
                                editBuffer = textBody ?? ""
                                isEditing = true
                            } label: {
                                Label(localizer.t.filesEdit, systemImage: "pencil")
                            }
                        }
                        if isEditing {
                            Button {
                                Task { await saveText() }
                            } label: {
                                Label(localizer.t.filesSave, systemImage: "square.and.arrow.down")
                            }
                            .disabled(isSaving)
                        }
                        if kind == .markdown, !isEditing {
                            Button {
                                showMarkdownRendered.toggle()
                            } label: {
                                Label(
                                    showMarkdownRendered ? localizer.t.filesShowSource : localizer.t.filesShowPreview,
                                    systemImage: showMarkdownRendered ? "chevron.left.forwardslash.chevron.right" : "doc.richtext"
                                )
                            }
                        }
                        Button(action: onDownload) {
                            Label(localizer.t.filesDownload, systemImage: "arrow.down.circle")
                        }
                        Button(action: onCopyLink) {
                            Label(localizer.t.filesCopyLink, systemImage: "link")
                        }
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Label(localizer.t.delete, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .task(id: previewTaskKey) {
                guard !isLoading else { return }
                await preparePreview()
            }
        }
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                previewPane
                    .frame(maxWidth: .infinity)
                metaCard
            }
            .padding(16)
            .padding(.bottom, 72)
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        switch kind {
        case .video, .audio:
            mediaPlayerCard
        case .image:
            imagePane
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .markdown:
            Group { if isEditing { editorPane } else { markdownPane } }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .html:
            Group { if isEditing { editorPane } else { htmlPane } }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .text:
            Group { if isEditing { editorPane } else { textPane } }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .pdf:
            pdfPane
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .download, .none:
            fallbackPane
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Page 1: cover (OpenList thumb) + play. Fullscreen page auto-plays.
    private var mediaPlayerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .aspectRatio(kind == .audio ? 1.0 : 16 / 9, contentMode: .fit)

                // Cover from OpenList `thumb` when present
                if let cover = coverURL {
                    AsyncImage(url: cover) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty:
                            ProgressView().tint(.white)
                        default:
                            mediaPlaceholderIcon
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    mediaPlaceholderIcon
                }

                // Dim + play overlay
                LinearGradient(
                    colors: [.black.opacity(0.15), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 12) {
                    if isLoading && streamURL == nil {
                        ProgressView().tint(.white)
                    } else {
                        Spacer(minLength: 0)
                        Button(action: onPlayBuiltIn) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 64))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white)
                                .shadow(radius: 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(streamURL == nil && !isLoading)
                        .accessibilityLabel(localizer.t.filesPlay)

                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 16)
                            .shadow(radius: 2)

                        if streamURL == nil, !isLoading {
                            Text(localizer.t.filesNoPlayableURL)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer(minLength: 8)
                    }
                }
                .padding(.vertical, 12)
            }

            if kind == .video {
                Text(localizer.t.filesPlaySectionExternal)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                OpenListExternalPlayerList(
                    onSelect: { player in onOpenExternalPlayer(player) },
                    onCopyLink: { onCopyLink() },
                    copyLinkTitle: localizer.t.filesCopyLink
                )
            }

            HStack(spacing: 10) {
                Text(kindDisplayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(serviceColor)
                if !item.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var coverURL: URL? {
        detail?.item.thumbnailURL ?? item.thumbnailURL
    }

    private var mediaPlaceholderIcon: some View {
        Image(systemName: kind == .audio ? "music.note" : "film")
            .font(.system(size: 44, weight: .ultraLight))
            .foregroundStyle(.white.opacity(0.85))
    }

    private var imagePane: some View {
        Group {
            if let url = streamURL {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(maxWidth: .infinity).frame(height: 280)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(imageScale)
                                .frame(maxWidth: .infinity)
                                .gesture(
                                    MagnificationGesture().onChanged { value in
                                        imageScale = min(max(value, 1), 4)
                                    }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation {
                                        imageScale = imageScale > 1.1 ? 1 : 2
                                    }
                                }
                        case .failure:
                            placeholder(icon: "photo", text: localizer.t.filesPreviewFailed)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .frame(minHeight: 280)
                .background(Color.black.opacity(0.04))
            } else {
                placeholder(icon: "photo", text: localizer.t.filesNoPlayableURL)
            }
        }
    }

    @ViewBuilder
    private var markdownPane: some View {
        textContainer {
            if showMarkdownRendered {
                if let textBody {
                    Text(markdownAttributed(textBody))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            } else {
                monospacedText
            }
        }
    }

    private var textPane: some View {
        textContainer { monospacedText }
    }

    private var editorPane: some View {
        TextEditor(text: $editBuffer)
            .font(.system(.footnote, design: .monospaced))
            .frame(minHeight: 320)
            .padding(8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private var monospacedText: some View {
        if let textBody {
            Text(textBody)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func textContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if textLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else if let textError {
                placeholder(icon: "doc.text", text: textError)
            } else if textBody != nil {
                content()
                    .padding(14)
            } else {
                placeholder(icon: "doc.text", text: localizer.t.filesNoPlayableURL)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var htmlPane: some View {
        Group {
            if textLoading {
                ProgressView().frame(maxWidth: .infinity).frame(height: 320)
            } else if let textBody {
                HTMLPreviewWebView(html: textBody, baseURL: streamURL)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 360)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
            } else if let url = streamURL {
                HTMLURLWebView(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 360)
            } else {
                placeholder(icon: "chevron.left.forwardslash.chevron.right", text: localizer.t.filesNoPlayableURL)
            }
        }
    }

    private var pdfPane: some View {
        Group {
            if let url = streamURL {
                PDFKitRepresentedView(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 420)
            } else {
                placeholder(icon: "doc.richtext", text: localizer.t.filesNoPlayableURL)
            }
        }
    }

    private var fallbackPane: some View {
        VStack(spacing: 12) {
            Image(systemName: item.systemImageName)
                .font(.system(size: 48))
                .foregroundStyle(serviceColor)
            Text(item.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(localizer.t.filesNoInlinePreview)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: onDownload) {
                Label(localizer.t.filesDownload, systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(serviceColor)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func placeholder(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(AppTheme.textSecondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeled(localizer.t.filesNameLabel, item.name)
            labeled(localizer.t.filesPathLabel, item.path)
            if !item.isDirectory {
                labeled(
                    localizer.t.filesSizeLabel,
                    ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
                )
            }
            if let modified = item.modifiedAt {
                labeled(localizer.t.filesModifiedLabel, modified.formatted())
            }
            labeled(localizer.t.filesPreviewType, kindDisplayName)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .textSelection(.enabled)
        }
    }

    private var actionBar: some View {
        // Media already has inline player + external icons; only show bottom bar for non-media.
        Group {
            if kind == .video || kind == .audio {
                EmptyView()
            } else {
                HStack(spacing: 10) {
                    if item.isEditableText {
                        if isEditing {
                            Button {
                                Task { await saveText() }
                            } label: {
                                if isSaving {
                                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                                } else {
                                    Label(localizer.t.filesSave, systemImage: "square.and.arrow.down")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(serviceColor)
                            .disabled(isSaving)
                        } else {
                            Button {
                                editBuffer = textBody ?? ""
                                isEditing = true
                            } label: {
                                Label(localizer.t.filesEdit, systemImage: "pencil")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .tint(serviceColor)
                        }
                    }

                    Button(action: onDownload) {
                        Label(localizer.t.filesDownload, systemImage: "arrow.down.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(serviceColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Load / save

    @MainActor
    private func preparePreview() async {
        textBody = nil
        textError = nil
        isEditing = false
        switch kind {
        case .markdown, .text, .html:
            await loadText()
        case .video, .audio, .image, .pdf, .download, .none:
            break
        }
    }

    @MainActor
    private func loadText() async {
        textLoading = true
        textError = nil
        defer { textLoading = false }
        do {
            if let loadTextContent {
                textBody = try await loadTextContent()
                return
            }
            textError = localizer.t.filesNoPlayableURL
        } catch is CancellationError {
        } catch let error as APIError {
            textError = error.localizedDescription
        } catch {
            textError = error.localizedDescription
        }
    }

    @MainActor
    private func saveText() async {
        guard let client else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await client.writeTextFile(path: item.path, content: editBuffer)
            textBody = editBuffer
            isEditing = false
            onSaved()
        } catch {
            textError = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func markdownAttributed(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        if let parsed = try? AttributedString(markdown: source, options: options) {
            return parsed
        }
        return AttributedString(source)
    }
}

// MARK: - Web / PDF helpers

private struct HTMLPreviewWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}

private struct HTMLURLWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.isOpaque = false
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

private struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}
