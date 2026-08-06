import SwiftUI

/// Browse an OpenList folder and pick a subtitle file (.srt / .ass / …).
struct OpenListSubtitlePickerView: View {
    let client: OpenListAPIClient
    let startPath: String
    let onPick: (URL, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var localizer

    @State private var path: String
    @State private var items: [FileItem] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var isResolving = false

    private static let subtitleExts: Set<String> = ["srt", "vtt", "ass", "ssa", "sub"]
    private var serviceColor: Color { ServiceType.openlist.colors.primary }

    init(client: OpenListAPIClient, startPath: String, onPick: @escaping (URL, String) -> Void) {
        self.client = client
        self.startPath = startPath
        self.onPick = onPick
        _path = State(initialValue: startPath.isEmpty ? "/" : startPath)
    }

    private var folders: [FileItem] {
        items.filter(\.isDirectory).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var subtitles: [FileItem] {
        items.filter { item in
            !item.isDirectory && Self.subtitleExts.contains(item.fileExtension)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorText {
                    ContentUnavailableView(errorText, systemImage: "exclamationmark.triangle")
                } else if folders.isEmpty && subtitles.isEmpty {
                    ContentUnavailableView(
                        localizer.t.filesEmptyFolder,
                        systemImage: "captions.bubble",
                        description: Text(path)
                    )
                } else {
                    List {
                        if path != "/" {
                            Section {
                                Button {
                                    Task { await navigate(to: parentPath(of: path)) }
                                } label: {
                                    Label(localizer.t.back, systemImage: "arrow.up.left")
                                }
                            }
                        }

                        if !folders.isEmpty {
                            Section(localizer.t.filesFolderKind) {
                                ForEach(folders) { folder in
                                    Button {
                                        Task { await navigate(to: folder.path) }
                                    } label: {
                                        Label(folder.name, systemImage: "folder.fill")
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }

                        Section(localizer.t.filesPlayerSubtitlePickTitle) {
                            if subtitles.isEmpty {
                                Text(localizer.t.noData)
                                    .foregroundStyle(AppTheme.textMuted)
                            } else {
                                ForEach(subtitles) { item in
                                    Button {
                                        Task { await pick(item) }
                                    } label: {
                                        HStack {
                                            Label(item.name, systemImage: "captions.bubble")
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            if isResolving {
                                                ProgressView().controlSize(.small)
                                            }
                                        }
                                    }
                                    .disabled(isResolving)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(localizer.t.filesPlayerSubtitlePickTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.cancel) { dismiss() }
                }
            }
            .tint(serviceColor)
            .task { await reload() }
        }
    }

    private func parentPath(of path: String) -> String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return "/" }
        var parts = trimmed.split(separator: "/").map(String.init)
        guard parts.count > 1 else { return "/" }
        parts.removeLast()
        return "/" + parts.joined(separator: "/")
    }

    @MainActor
    private func navigate(to newPath: String) async {
        path = newPath.isEmpty ? "/" : newPath
        await reload()
    }

    @MainActor
    private func reload() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let listing = try await client.list(path: path)
            items = listing.items
        } catch {
            errorText = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            items = []
        }
    }

    @MainActor
    private func pick(_ item: FileItem) async {
        isResolving = true
        defer { isResolving = false }
        do {
            let detail = try await client.detail(path: item.path)
            guard let url = detail.contentURL ?? detail.playURL else {
                errorText = localizer.t.filesPlayerSubtitleLoadFailed
                return
            }
            onPick(url, item.name)
            dismiss()
        } catch {
            errorText = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }
}
