import SwiftUI

/// First-version style: text rows with SF Symbol, not icon-only badges.
struct OpenListExternalPlayerList: View {
    let onSelect: (ExternalPlayerOption) -> Void
    var onCopyLink: (() -> Void)? = nil
    var copyLinkTitle: String = "Copy link"
    var includeSystem: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            ForEach(players) { player in
                Button {
                    onSelect(player)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: player.systemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(player.accentColor)
                            .frame(width: 28)
                        Text(player.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                    )
                }
                .buttonStyle(.plain)
            }

            if let onCopyLink {
                Button(action: onCopyLink) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text(copyLinkTitle)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var players: [ExternalPlayerOption] {
        includeSystem ? Array(ExternalPlayerOption.allCases) : ExternalPlayerOption.allCases.filter { $0 != .system }
    }
}

/// Sheet chooser: simple text list (first-version style).
struct OpenListPlayerPickerView: View {
    let fileName: String
    let onExternal: (ExternalPlayerOption) -> Void
    let onCopyLink: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var localizer

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !fileName.isEmpty {
                        Text(fileName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    OpenListExternalPlayerList(
                        onSelect: { player in
                            dismiss()
                            onExternal(player)
                        },
                        onCopyLink: {
                            dismiss()
                            onCopyLink()
                        },
                        copyLinkTitle: localizer.t.filesCopyLink
                    )

                    Text(localizer.t.filesPlayFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .navigationTitle(localizer.t.filesPlayWith)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// Back-compat names used by older call sites.
typealias OpenListExternalPlayerStrip = OpenListExternalPlayerListCompat
typealias OpenListExternalPlayerGrid = OpenListExternalPlayerListCompat

struct OpenListExternalPlayerListCompat: View {
    var iconSize: CGFloat = 40
    var columns: Int = 3
    var compact: Bool = false
    let onSelect: (ExternalPlayerOption) -> Void
    var onCopyLink: (() -> Void)? = nil

    var body: some View {
        OpenListExternalPlayerList(onSelect: onSelect, onCopyLink: onCopyLink)
    }
}
