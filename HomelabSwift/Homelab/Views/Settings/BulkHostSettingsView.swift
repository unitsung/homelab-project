import SwiftUI

/// Settings screen: replace the host of all configured service URLs in one step.
struct BulkHostSettingsView: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer
    @Environment(\.dismiss) private var dismiss

    @State private var hostInput = ""
    @State private var scope: ServiceHostBulkReplacer.Scope = .both
    @State private var showConfirm = false
    @State private var isApplying = false
    @State private var resultMessage: String?
    @State private var showResult = false

    private var normalizedHost: String? {
        ServiceHostBulkReplacer.normalizeHostInput(hostInput)
    }

    private var previewRows: [ServiceHostBulkReplacer.PreviewRow] {
        guard let host = normalizedHost else { return [] }
        return ServiceHostBulkReplacer.preview(
            instances: servicesStore.allInstances,
            newHost: host,
            scope: scope
        )
    }

    private var hostFieldError: String? {
        let trimmed = hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if normalizedHost == nil { return localizer.t.settingsBulkHostInvalid }
        return nil
    }

    var body: some View {
        List {
            Section {
                TextField(localizer.t.settingsBulkHostPlaceholder, text: $hostInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.body.monospaced())

                if let hostFieldError {
                    Text(hostFieldError)
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                } else if let host = normalizedHost {
                    Text(String(format: localizer.t.settingsBulkHostNormalized, host))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } header: {
                Text(localizer.t.settingsBulkHost)
            } footer: {
                Text(localizer.t.settingsBulkHostHint)
            }

            Section(localizer.t.settingsBulkHostScope) {
                Picker(localizer.t.settingsBulkHostScope, selection: $scope) {
                    Text(localizer.t.settingsBulkHostPrimary).tag(ServiceHostBulkReplacer.Scope.primary)
                    Text(localizer.t.settingsBulkHostFallback).tag(ServiceHostBulkReplacer.Scope.fallback)
                    Text(localizer.t.settingsBulkHostBoth).tag(ServiceHostBulkReplacer.Scope.both)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            Section {
                if servicesStore.allInstances.isEmpty {
                    Text(localizer.t.settingsNoInstances)
                        .foregroundStyle(AppTheme.textMuted)
                } else if normalizedHost == nil {
                    Text(localizer.t.settingsBulkHostPreviewEmpty)
                        .foregroundStyle(AppTheme.textMuted)
                } else if previewRows.isEmpty {
                    Text(localizer.t.settingsBulkHostNoChanges)
                        .foregroundStyle(AppTheme.textMuted)
                } else {
                    ForEach(previewRows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "server.rack")
                                    .foregroundStyle(row.type.colors.primary)
                                Text(row.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Text(row.type.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                            if row.primaryChanged {
                                urlChangeLine(
                                    title: localizer.t.settingsBulkHostPrimary,
                                    from: row.oldPrimary,
                                    to: row.newPrimary
                                )
                            }
                            if row.fallbackChanged, let oldFb = row.oldFallback, let newFb = row.newFallback {
                                urlChangeLine(
                                    title: localizer.t.settingsBulkHostFallback,
                                    from: oldFb,
                                    to: newFb
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text(localizer.t.settingsBulkHostPreview)
            }

            Section {
                Button {
                    showConfirm = true
                } label: {
                    if isApplying {
                        HStack {
                            ProgressView()
                            Text(localizer.t.settingsBulkHostApplying)
                        }
                    } else {
                        Text(localizer.t.settingsBulkHostApply)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(normalizedHost == nil || previewRows.isEmpty || isApplying)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(localizer.t.settingsBulkHost)
        .navigationBarTitleDisplayMode(.inline)
        .alert(localizer.t.settingsBulkHostConfirmTitle, isPresented: $showConfirm) {
            Button(localizer.t.cancel, role: .cancel) {}
            Button(localizer.t.settingsBulkHostApply, role: .destructive) {
                Task { await apply() }
            }
        } message: {
            Text(String(format: localizer.t.settingsBulkHostConfirmBody, previewRows.count, normalizedHost ?? ""))
        }
        .alert(localizer.t.settingsBulkHost, isPresented: $showResult) {
            Button(localizer.t.confirm, role: .cancel) {
                if previewRows.isEmpty { dismiss() }
            }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private func urlChangeLine(title: String, from: String, to: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)
            Text(from)
                .font(.caption2.monospaced())
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            Image(systemName: "arrow.down")
                .font(.caption2)
                .foregroundStyle(AppTheme.textMuted)
            Text(to)
                .font(.caption2.monospaced())
                .foregroundStyle(AppTheme.accent)
                .lineLimit(2)
        }
    }

    @MainActor
    private func apply() async {
        guard let host = normalizedHost else { return }
        isApplying = true
        defer { isApplying = false }
        let count = await servicesStore.applyHostReplace(newHost: host, scope: scope)
        resultMessage = String(format: localizer.t.settingsBulkHostApplied, count)
        showResult = true
        HapticManager.medium()
    }
}
