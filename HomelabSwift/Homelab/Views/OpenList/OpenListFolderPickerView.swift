import SwiftUI

/// Simple folder navigator to pick a destination for move / copy / extract.
struct OpenListFolderPickerView: View {
    let client: OpenListAPIClient
    let title: String
    let confirmTitle: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var localizer
    @State private var path: String = "/"
    @State private var folders: [FileItem] = []
    @State private var isLoading = true
    @State private var errorText: String?

    private var crumbs: [FileBreadcrumb] { OpenListPath.breadcrumbs(for: path) }

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let errorText {
                    Text(errorText).foregroundStyle(.red)
                } else {
                    Section {
                        ForEach(folders) { folder in
                            Button {
                                Task { await navigate(to: folder.path) }
                            } label: {
                                Label(folder.name, systemImage: "folder.fill")
                            }
                        }
                    } header: {
                        Text(path)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        onPick(path)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                                if index > 0 {
                                    Image(systemName: "chevron.right").font(.caption2)
                                }
                                Button(index == 0 ? localizer.t.filesRootTitle : crumb.title) {
                                    Task { await navigate(to: crumb.path) }
                                }
                                .font(.caption.weight(index == crumbs.count - 1 ? .semibold : .regular))
                            }
                        }
                    }
                }
            }
            .task { await navigate(to: "/") }
        }
    }

    @MainActor
    private func navigate(to newPath: String) async {
        isLoading = true
        errorText = nil
        path = OpenListPath.normalize(newPath)
        do {
            let result = try await client.list(path: path)
            folders = result.items.filter(\.isDirectory)
            isLoading = false
        } catch {
            errorText = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            isLoading = false
        }
    }
}
