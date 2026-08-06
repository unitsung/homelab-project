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
    @State private var navDirection: OpenListFolderNavDirection = .none
    @State private var navigateGeneration = 0
    @State private var errorText: String?

    private var crumbs: [FileBreadcrumb] { OpenListPath.breadcrumbs(for: path) }
    private var serviceColor: Color { ServiceType.openlist.colors.primary }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    folderLoadingPlaceholder
                        .transition(.opacity)
                } else if let errorText {
                    ContentUnavailableView(
                        errorText,
                        systemImage: "exclamationmark.triangle"
                    )
                    .transition(.opacity)
                } else if folders.isEmpty {
                    ContentUnavailableView(
                        localizer.t.filesEmptyFolder,
                        systemImage: "folder",
                        description: Text(path)
                    )
                    .id("empty-\(path)")
                    .transition(contentTransition)
                } else {
                    List {
                        Section {
                            ForEach(folders) { folder in
                                Button {
                                    Task { await navigate(to: folder.path) }
                                } label: {
                                    Label(folder.name, systemImage: "folder.fill")
                                        .foregroundStyle(.primary)
                                }
                                .disabled(isLoading)
                            }
                        } header: {
                            Text(path)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .id("list-\(path)")
                    .transition(contentTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.28), value: isLoading)
            .animation(.easeInOut(duration: 0.28), value: path)
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
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .bottomBar) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                                if index > 0 {
                                    Image(systemName: "chevron.right").font(.caption2)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Button(index == 0 ? localizer.t.filesRootTitle : crumb.title) {
                                    Task { await navigate(to: crumb.path) }
                                }
                                .font(.caption.weight(index == crumbs.count - 1 ? .semibold : .regular))
                                .foregroundStyle(index == crumbs.count - 1 ? Color.primary : serviceColor)
                                .disabled(index == crumbs.count - 1 || isLoading)
                            }
                        }
                    }
                }
            }
            .task { await navigate(to: "/") }
        }
    }

    private var contentTransition: AnyTransition {
        switch navDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .none:
            return .opacity
        }
    }

    private var folderLoadingPlaceholder: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(localizer.t.loading)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)
            }
            ForEach(0..<5, id: \.self) { _ in
                SkeletonRow()
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @MainActor
    private func navigate(to newPath: String) async {
        let normalized = OpenListPath.normalize(newPath)
        let from = path
        let previousFolders = folders

        let fromDepth = pathDepth(from)
        let toDepth = pathDepth(normalized)
        if toDepth > fromDepth {
            navDirection = .forward
        } else if toDepth < fromDepth {
            navDirection = .backward
        } else {
            navDirection = .none
        }

        navigateGeneration += 1
        let generation = navigateGeneration

        errorText = nil
        withAnimation(.easeInOut(duration: 0.22)) {
            path = normalized
            folders = []
            isLoading = true
        }

        do {
            let result = try await client.list(path: normalized)
            guard generation == navigateGeneration else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                folders = result.items.filter(\.isDirectory)
                isLoading = false
            }
        } catch {
            guard generation == navigateGeneration else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                path = from
                folders = previousFolders
                isLoading = false
                navDirection = navDirection.reversed
            }
            errorText = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func pathDepth(_ path: String) -> Int {
        let n = OpenListPath.normalize(path)
        if n == "/" { return 0 }
        return n.split(separator: "/").filter { !$0.isEmpty }.count
    }
}
