import SwiftUI
import LocalAuthentication
import UIKit

// Maps to app/(tabs)/settings/index.tsx

struct SettingsView: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(Localizer.self) private var localizer

    @State private var showDisableSecurityAlert = false
    @State private var showChangePinFlow = false
    @State private var changePinStep: ChangePinStep = .currentPin
    @State private var currentPinInput = ""
    @State private var newPinInput = ""
    @State private var confirmPinInput = ""
    @State private var changePinError: String? = nil
    @State private var showDebugLogs = false
    @State private var showDebugAuthPin = false
    @State private var debugAuthPin = ""
    @State private var debugAuthError: String? = nil
    /// Language / About start collapsed (common pattern for secondary settings).
    @State private var isLanguageExpanded = false
    @State private var isAboutExpanded = false

    private var connectedInstanceCount: Int {
        servicesStore.allInstances.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    GlassGroup(spacing: 20) {
                        VStack(alignment: .leading, spacing: 22) {
                            // Large title (iOS Settings-style)
                            Text(localizer.t.tabSettings)
                                .font(.largeTitle.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)

                            updateBannerSection

                            // 1. Service connections
                            servicesSection

                            // 2. Appearance (theme + icon)
                            appearanceSection

                            // 3. Language
                            languageSection

                            // 4. Security & data
                            securitySection
                            backupSection

                            // 5. Developer
                            debugSection

                            // 6. About (collapsed by default)
                            aboutSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(localizer.t.confirm) {
                            endEditing()
                        }
                    }
                }
            }
            .onTapGesture { endEditing() }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task {
                await settingsStore.checkForUpdatesIfNeeded()
            }
        }
        .sheet(isPresented: $showDebugLogs) {
            DebugLogsView()
        }
        .alert(localizer.t.securityEnterPin, isPresented: $showDebugAuthPin) {
            SecureField(localizer.t.securityEnterPinDesc, text: $debugAuthPin)
                .keyboardType(.numberPad)
            Button(localizer.t.cancel, role: .cancel) {
                debugAuthPin = ""
                debugAuthError = nil
            }
            Button(localizer.t.confirm) {
                if settingsStore.verifyPin(debugAuthPin) {
                    showDebugAuthPin = false
                    debugAuthPin = ""
                    debugAuthError = nil
                    showDebugLogs = true
                } else {
                    debugAuthError = localizer.t.securityWrongPin
                    debugAuthPin = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        debugAuthError = nil
                    }
                }
            }
        } message: {
            Text(debugAuthError ?? localizer.t.debugLogsAuthMessage)
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    private func settingsIcon(_ systemName: String, color: Color = AppTheme.accent) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private var updateBannerSection: some View {
        if let latest = settingsStore.availableUpdateVersion {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                    Text(localizer.t.settingsUpdateBannerTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                }

                Text(String(format: localizer.t.settingsUpdateBannerBody, latest, appVersion))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        if let urlString = settingsStore.availableUpdateURL,
                           let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(localizer.t.settingsUpdateAction, systemImage: "arrow.up.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)

                    Button {
                        settingsStore.dismissUpdateBanner()
                    } label: {
                        Text(localizer.t.settingsUpdateDismiss)
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .glassCard(tint: AppTheme.accent.opacity(0.08))
        }
    }

    // MARK: Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localizer.t.settingsServicesGroup)

            NavigationLink {
                AuthGatedConfiguredServicesView()
            } label: {
                HStack(spacing: 14) {
                    settingsIcon("server.rack", color: Color(hex: "#3B82F6"))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizer.t.settingsConfiguredServices)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(localizer.t.settingsConfiguredServicesDesc)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    if connectedInstanceCount > 0 {
                        Text("\(connectedInstanceCount)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accent.opacity(0.9), in: Capsule())
                    }

                    if settingsStore.isPinSet {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localizer.t.settingsAppearance)

            VStack(spacing: 0) {
                // Theme
                VStack(alignment: .leading, spacing: 10) {
                    Text(localizer.t.settingsTheme)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            let selected = settingsStore.theme == mode
                            Button {
                                settingsStore.theme = mode
                                HapticManager.light()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: themeSymbol(mode))
                                        .font(.caption.weight(.semibold))
                                    Text(themeLabel(mode))
                                        .font(.subheadline.weight(selected ? .semibold : .regular))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    selected ? AppTheme.accent.opacity(0.16) : Color(.tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .foregroundStyle(selected ? AppTheme.accent : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)

                if UIApplication.shared.supportsAlternateIcons {
                    Divider().padding(.leading, 14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizer.t.settingsAppIcon)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AppIconOption.allCases, id: \.self) { iconOption in
                                    let selected = settingsStore.appIcon == iconOption
                                    Button {
                                        settingsStore.setAppIcon(iconOption)
                                        HapticManager.light()
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack(alignment: .bottomTrailing) {
                                                appIconPreview(for: iconOption)
                                                    .frame(width: 52, height: 52)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(
                                                                selected ? AppTheme.accent : Color.primary.opacity(0.08),
                                                                lineWidth: selected ? 2.5 : 1
                                                            )
                                                    )

                                                if selected {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.caption.weight(.bold))
                                                        .symbolRenderingMode(.palette)
                                                        .foregroundStyle(.white, AppTheme.accent)
                                                        .offset(x: 4, y: 4)
                                                }
                                            }
                                            Text(label(for: iconOption))
                                                .font(.caption2)
                                                .foregroundStyle(selected ? AppTheme.accent : AppTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 64)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(label(for: iconOption))
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(14)
                }
            }
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: Language (collapsed by default; list + checkmark)

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localizer.t.settingsLanguage)

            VStack(spacing: 0) {
                collapsibleHeader(
                    title: localizer.t.settingsLanguage,
                    subtitle: languagePrimaryName(settingsStore.language),
                    systemImage: "globe",
                    color: Color(hex: "#0EA5E9"),
                    isExpanded: isLanguageExpanded
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLanguageExpanded.toggle()
                    }
                    HapticManager.light()
                }

                if isLanguageExpanded {
                    Divider().padding(.leading, 58)

                    ForEach(Array(Language.allCases.enumerated()), id: \.element) { index, lang in
                        Button {
                            settingsStore.language = lang
                            localizer.language = lang
                            HapticManager.selection()
                        } label: {
                            HStack(spacing: 14) {
                                Text(languagePrimaryName(lang))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(languageSecondaryName(lang))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textMuted)

                                Image(systemName: settingsStore.language == lang ? "checkmark" : "")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 22)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(settingsStore.language == lang ? .isSelected : [])

                        if index < Language.allCases.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .glassCard(cornerRadius: 16)
            .animation(.easeInOut(duration: 0.2), value: isLanguageExpanded)
        }
    }

    private func languagePrimaryName(_ lang: Language) -> String {
        switch lang {
        case .zh: return "中文"
        case .en: return "English"
        }
    }

    private func languageSecondaryName(_ lang: Language) -> String {
        // Secondary label in the *other* script helps bilingual users.
        switch lang {
        case .zh: return "Chinese"
        case .en: return "英语"
        }
    }

    private func label(for icon: AppIconOption) -> String {
        switch icon {
        case .default: return localizer.t.settingsAppIconDefault
        case .dark: return localizer.t.settingsAppIconDark
        case .clearLight: return localizer.t.settingsAppIconClearLight
        case .clearDark: return localizer.t.settingsAppIconClearDark
        case .tintedLight: return localizer.t.settingsAppIconTintedLight
        case .tintedDark: return localizer.t.settingsAppIconTintedDark
        }
    }

    private func themeSymbol(_ mode: ThemeMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    // MARK: About (collapsed by default — version / source / updates only)

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localizer.t.settingsAbout)

            VStack(spacing: 0) {
                collapsibleHeader(
                    title: localizer.t.settingsAbout,
                    subtitle: appVersionLabel,
                    systemImage: "info.circle.fill",
                    color: Color(hex: "#6366F1"),
                    isExpanded: isAboutExpanded
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAboutExpanded.toggle()
                    }
                    HapticManager.light()
                }

                if isAboutExpanded {
                    Divider().padding(.leading, 58)

                    // Version (not tappable)
                    HStack(spacing: 14) {
                        settingsIcon("app.badge.fill", color: Color(hex: "#6366F1"))
                        Text(localizer.t.settingsVersion)
                            .font(.body.weight(.medium))
                        Spacer()
                        Text(appVersionLabel)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)

                    Divider().padding(.leading, 58)

                    settingsLinkRow(
                        title: localizer.t.settingsAboutSource,
                        subtitle: "github.com/unitsung/homelab-project",
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        color: Color(hex: "#111827"),
                        url: "https://github.com/unitsung/homelab-project"
                    )

                    Divider().padding(.leading, 58)

                    Button {
                        HapticManager.light()
                        Task { await settingsStore.checkForUpdatesIfNeeded(force: true) }
                    } label: {
                        HStack(spacing: 14) {
                            settingsIcon("arrow.triangle.2.circlepath", color: Color(hex: "#0EA5E9"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localizer.t.settingsCheckForUpdatesNow)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(localizer.t.settingsCheckForUpdatesDesc)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassCard(cornerRadius: 16)
            .animation(.easeInOut(duration: 0.2), value: isAboutExpanded)
        }
    }

    private func collapsibleHeader(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                settingsIcon(systemImage, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExpanded ? localizer.t.settingsCollapse : localizer.t.settingsExpand)
    }

    private func settingsLinkRow(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        url: String
    ) -> some View {
        Button {
            if let u = URL(string: url) {
                HapticManager.light()
                UIApplication.shared.open(u)
            }
        } label: {
            HStack(spacing: 14) {
                settingsIcon(systemImage, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func appIconPreview(for icon: AppIconOption) -> some View {
        if let image = UIImage(named: icon.previewAssetName) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: settingsStore.appIcon == icon ? "app.badge.fill" : "app")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(settingsStore.appIcon == icon ? AppTheme.accent : AppTheme.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.tertiarySystemFill))
        }
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localizer.t.settingsDebug)

            Button {
                HapticManager.light()
                if settingsStore.isPinSet {
                    showDebugAuthPin = true
                } else {
                    showDebugLogs = true
                }
            } label: {
                HStack(spacing: 14) {
                    settingsIcon("terminal.fill", color: Color(hex: "#64748B"))
                    Text(localizer.t.settingsDebugLogs)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localizer.t.securityTitle)

            VStack(spacing: 0) {
                // Biometric toggle
                if settingsStore.isPinSet {
                    let context = LAContext()
                    let canUseBiometric = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
                    let biometricLabel = context.biometryType == .faceID ? localizer.t.securityFaceId : localizer.t.securityTouchId

                    if canUseBiometric {
                        HStack {
                            Image(systemName: context.biometryType == .faceID ? "faceid" : "touchid")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 32, height: 32)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(biometricLabel)
                                    .font(.body.weight(.medium))
                                Text(localizer.t.securityBiometricDesc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { settingsStore.biometricEnabled },
                                set: { settingsStore.biometricEnabled = $0 }
                            ))
                            .labelsHidden()
                            .tint(AppTheme.accent)
                        }
                        .padding(16)

                        Divider().padding(.horizontal, 16)
                    }

                    // Change PIN
                    Button {
                        changePinStep = .currentPin
                        currentPinInput = ""
                        newPinInput = ""
                        confirmPinInput = ""
                        changePinError = nil
                        showChangePinFlow = true
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 32, height: 32)

                            Text(localizer.t.securityChangePin)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textMuted)
                                .accessibilityHidden(true)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.horizontal, 16)

                    // Disable security
                    Button {
                        showDisableSecurityAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.slash.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.danger)
                                .frame(width: 32, height: 32)

                            Text(localizer.t.securityDisable)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.danger)

                            Spacer()
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    // No PIN set — offer to set up
                    Button {
                        changePinStep = .newPin
                        currentPinInput = ""
                        newPinInput = ""
                        confirmPinInput = ""
                        changePinError = nil
                        showChangePinFlow = true
                        HapticManager.light()
                    } label: {
                        HStack {
                            Image(systemName: "lock.open.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 32, height: 32)
                                .accessibilityHidden(true)

                            Text(localizer.t.securitySetupPin)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textMuted)
                                .accessibilityHidden(true)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassCard()
        }
        .alert(localizer.t.securityDisableConfirm, isPresented: $showDisableSecurityAlert) {
            Button(localizer.t.cancel, role: .cancel) { }
            Button(localizer.t.securityDisable, role: .destructive) {
                settingsStore.clearSecurity()
                HapticManager.medium()
            }
        } message: {
            Text(localizer.t.securityDisableMessage)
        }
        .fullScreenCover(isPresented: $showChangePinFlow) {
            changePinView
        }
    }

    // MARK: - Backup Section

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localizer.t.backupTitle)

            NavigationLink(destination: BackupView()) {
                HStack(spacing: 14) {
                    settingsIcon("externaldrive.fill.badge.timemachine", color: Color(hex: "#10B981"))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizer.t.backupTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(localizer.t.backupInfoDesc)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Change PIN Flow

    @ViewBuilder
    private var changePinView: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        showChangePinFlow = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .padding(12)
                    }
                    .accessibilityLabel(localizer.t.close)
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 8)

                switch changePinStep {
                case .currentPin:
                    PinEntryView(
                        pin: $currentPinInput,
                        title: localizer.t.securityCurrentPin,
                        subtitle: localizer.t.securityCurrentPinDesc,
                        errorMessage: changePinError,
                        onComplete: { pin in
                            if settingsStore.verifyPin(pin) {
                                changePinError = nil
                                currentPinInput = ""
                                withAnimation {
                                    changePinStep = .newPin
                                }
                            } else {
                                changePinError = localizer.t.securityWrongPin
                                currentPinInput = ""
                                HapticManager.error()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    changePinError = nil
                                }
                            }
                        }
                    )

                case .newPin:
                    PinEntryView(
                        pin: $newPinInput,
                        title: localizer.t.securityNewPin,
                        subtitle: localizer.t.securityNewPinDesc,
                        onComplete: { _ in
                            withAnimation {
                                changePinStep = .confirmNewPin
                            }
                        }
                    )

                case .confirmNewPin:
                    PinEntryView(
                        pin: $confirmPinInput,
                        title: localizer.t.securityConfirmPin,
                        subtitle: localizer.t.securityConfirmPinDesc,
                        errorMessage: changePinError,
                        onComplete: { pin in
                            if pin == newPinInput {
                                settingsStore.savePin(pin)
                                HapticManager.success()
                                showChangePinFlow = false
                            } else {
                                changePinError = localizer.t.securityPinMismatch
                                confirmPinInput = ""
                                newPinInput = ""
                                HapticManager.error()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    changePinError = nil
                                    withAnimation {
                                        changePinStep = .newPin
                                    }
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func themeLabel(_ mode: ThemeMode) -> String {
        switch mode {
        case .dark: return localizer.t.settingsThemeDark
        case .light: return localizer.t.settingsThemeLight
        case .system: return localizer.t.settingsThemeAuto
        }
    }

    /// Marketing version, e.g. `1.6.2`.
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        if let version, !version.isEmpty { return version }
        return "—"
    }

    /// Build number (CFBundleVersion), e.g. `39`.
    private var appBuild: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        if let build, !build.isEmpty { return build }
        return "—"
    }

    /// Industry-common label: `1.6.2 (39)`.
    private var appVersionLabel: String {
        "\(appVersion) (\(appBuild))"
    }

}

// MARK: - ChangePinStep

enum ChangePinStep {
    case currentPin, newPin, confirmNewPin
}



// MARK: - Subviews

struct ContactRow: View {
    let title: String
    var subtitle: String? = nil
    let iconUrl: String
    let fallbackSystemName: String
    let url: String
    let color: Color

    private var iconAsset: some View {
        guard let url = URL(string: iconUrl) else {
            return AnyView(
                Image(systemName: fallbackSystemName)
                    .font(.title3)
                    .foregroundStyle(color)
            )
        }

        return AnyView(
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(color)
                case .success(let image):
                    image
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                case .failure:
                    Image(systemName: fallbackSystemName)
                        .font(.title3)
                        .foregroundStyle(color)
                @unknown default:
                    Image(systemName: fallbackSystemName)
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
        )
    }

    var body: some View {
        Button {
            if let url = URL(string: url) {
                HapticManager.light()
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.1))
                    iconAsset
                        .frame(width: 22, height: 22)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .clipShape(Capsule())
            .padding(.bottom, 24)
            .shadow(radius: 10)
    }
}

// MARK: - Debug Log View

struct DebugLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var localizer
    @State private var logStore = LogStore.shared
    @State private var showCopiedBanner = false
    @State private var scrollProxy: ScrollViewProxy?

    // Filter state
    @State private var selectedLevels: Set<LogStore.LogLevel> = Set(LogStore.LogLevel.allCases)
    @State private var selectedSources: Set<String> = []
    @State private var searchText = ""
    @State private var showFilters = true

    // All unique sources currently in the log
    private var availableSources: [String] {
        Array(Set(logStore.entries.map { $0.source })).sorted()
    }

    private var filteredEntries: [LogStore.LogEntry] {
        let reversed = Array(logStore.entries.reversed())
        return reversed.filter { entry in
            // Level filter
            guard selectedLevels.contains(entry.level) else { return false }
            // Source filter (empty = show all)
            if !selectedSources.isEmpty && !selectedSources.contains(entry.source) {
                return false
            }
            // Text search
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return entry.message.lowercased().contains(query)
                    || entry.source.lowercased().contains(query)
                    || entry.level.rawValue.lowercased().contains(query)
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.premiumGradient().ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter section (animated)
                    if showFilters {
                        filterSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Count badge + on-disk path (for simctl / agent pull)
                    VStack(alignment: .leading, spacing: 4) {
                        if !logStore.entries.isEmpty {
                            let filtered = filteredEntries
                            Text("\(filtered.count) / \(logStore.entries.count)")
                                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        if let path = (logStore.documentsLogFileURL ?? logStore.primaryLogFileURL)?.path {
                            Text(path)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)

                    // Empty state — no logs at all
                    if logStore.entries.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(AppTheme.textMuted)
                            Text(localizer.t.debugLogsEmpty)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(32)
                        Spacer()
                    }
                    // Empty state — filters too strict
                    else if filteredEntries.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(AppTheme.textMuted)
                            Text(localizer.t.debugLogsNoResults)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                        Spacer()
                    }
                    // Log list
                    else {
                        ScrollViewReader { proxy in
                            List {
                                ForEach(filteredEntries) { entry in
                                    logRow(entry)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                                        .id(entry.id)
                                }
                            }
                            .listStyle(.plain)
                            .background(Color.clear)
                            .onAppear { scrollProxy = proxy }
                        }
                    }
                }

                // Copied banner
                if showCopiedBanner {
                    VStack {
                        Spacer()
                        Text(localizer.t.debugLogsCopied)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(AppTheme.accent.opacity(0.9), in: Capsule())
                            .shadow(radius: 10)
                            .padding(.bottom, 40)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .ignoresSafeArea()
                    .zIndex(1)
                }
            }
            .navigationTitle(localizer.t.settingsDebugLogs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.t.close) { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        // Scroll to newest
                        Button {
                            if let first = filteredEntries.first {
                                withAnimation(.snappy(duration: 0.3)) {
                                    scrollProxy?.scrollTo(first.id, anchor: .top)
                                }
                            }
                            HapticManager.light()
                        } label: {
                            Image(systemName: "arrow.up.to.line")
                        }

                        // Toggle filters
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                showFilters.toggle()
                            }
                            HapticManager.light()
                        } label: {
                            Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }

                        // Share log file (disk) for agent / Mac pull
                        if let fileURL = logStore.documentsLogFileURL ?? logStore.primaryLogFileURL {
                            ShareLink(item: fileURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }

                        // Copy logs
                        Button {
                            copyLogs()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }

                        // Clear logs
                        Button {
                            logStore.clear()
                            HapticManager.light()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: 10) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)
                TextField(localizer.t.debugLogsSearchPlaceholder, text: $searchText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: AppTheme.smallRadius)

            // Level chips
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(LogStore.LogLevel.allCases, id: \.rawValue) { level in
                        levelChip(level)
                    }
                }
            }

            // Source chips (only show if there are multiple sources)
            if availableSources.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(availableSources, id: \.self) { source in
                                sourceChip(source)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Level chip

    private func levelChip(_ level: LogStore.LogLevel) -> some View {
        let isSelected = selectedLevels.contains(level)
        let tint = colorForLevel(level)

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isSelected {
                    selectedLevels.remove(level)
                } else {
                    selectedLevels.insert(level)
                }
            }
            HapticManager.light()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: level.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(level.rawValue)
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
            }
            .foregroundStyle(isSelected ? tint : AppTheme.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .glassCard(cornerRadius: AppTheme.pillRadius, tint: isSelected ? tint.opacity(0.15) : nil)
            .opacity(isSelected ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source chip

    private func sourceChip(_ source: String) -> some View {
        let isSelected = selectedSources.contains(source)
        let showAll = selectedSources.isEmpty

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isSelected {
                    selectedSources.remove(source)
                } else {
                    selectedSources.insert(source)
                }
            }
            HapticManager.light()
        } label: {
            Text(source)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.accent : (showAll ? .primary : AppTheme.textMuted))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassCard(cornerRadius: AppTheme.pillRadius, tint: isSelected ? AppTheme.accent.opacity(0.15) : nil)
                .opacity(isSelected || showAll ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Log Row

    private func logRow(_ entry: LogStore.LogEntry) -> some View {
        HStack(spacing: 0) {
            // Color accent strip
            RoundedRectangle(cornerRadius: 2)
                .fill(colorForLevel(entry.level))
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: entry.level.icon)
                        .font(.caption2)
                        .foregroundStyle(colorForLevel(entry.level))

                    Text(entry.formattedTime)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(entry.level.rawValue)
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(colorForLevel(entry.level))

                    Spacer()

                    Text(entry.source)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.08), in: Capsule())
                }

                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func colorForLevel(_ level: LogStore.LogLevel) -> Color {
        switch level {
        case .debug: return .secondary
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        case .network: return .purple
        }
    }

    private func copyLogs() {
        UIPasteboard.general.string = logStore.export()
        HapticManager.success()
        withAnimation {
            showCopiedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedBanner = false
            }
        }
    }
}
