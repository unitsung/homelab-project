import SwiftUI

// Maps to app/(tabs)/_layout.tsx
// iOS 26: TabView automatically gets Liquid Glass tab bar.
// The entire custom GlassTabBar.tsx (342 lines) is replaced by native TabView.

struct ContentView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(Localizer.self) private var localizer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            TabView {
                Tab(localizer.t.tabHome, systemImage: "house.fill") {
                    HomeView()
                }

                Tab(localizer.t.tabMedia, systemImage: "play.tv.fill") {
                    MediaDashboardView()
                }

                Tab(localizer.t.tabBookmarks, systemImage: "bookmark.fill") {
                    BookmarksView()
                }

                Tab(localizer.t.tabSettings, systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
            // Keep the tab bar fixed — auto-minimize on scroll is confusing for multi-tab navigation.
            .tabBarMinimizeBehavior(.never)

            // Update popup overlay
            if settingsStore.showUpdatePopup, let version = settingsStore.availableUpdateVersion {
                UpdatePopupView(
                    version: version,
                    changelog: settingsStore.availableUpdateChangelog,
                    onUpdate: {
                        if let urlString = settingsStore.availableUpdateURL, let url = URL(string: urlString) {
                            openURL(url)
                        }
                        settingsStore.dismissUpdatePopup()
                    },
                    onDismiss: {
                        settingsStore.dismissUpdatePopup()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(duration: 0.35), value: settingsStore.showUpdatePopup)
        .preferredColorScheme(colorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Network lifecycle is managed at App level.
                Task { await settingsStore.checkForUpdatesIfNeeded() }
            default:
                break
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch settingsStore.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Update Popup

struct UpdatePopupView: View {
    let version: String
    let changelog: String?
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    @Environment(Localizer.self) private var localizer

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Colored header section
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(.tint.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "arrow.down.app.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(.tint)
                        }

                        // Title
                        Text(localizer.t.updatePopupTitle)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        // Version badge
                        Text("v\(version)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.tint))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 24)

                    // Close button top-right
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .padding(.trailing, 16)
                }

                Divider()
                    .padding(.horizontal, 20)

                // Changelog
                if let changelog, !changelog.isEmpty {
                    ScrollView {
                        Text(changelog)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(minHeight: 180, maxHeight: 380)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.quaternary.opacity(0.5))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                } else {
                    Text(localizer.t.updatePopupBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                // Update button
                Button(action: onUpdate) {
                    Text(localizer.t.settingsUpdateAction)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.regularMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 40, y: 12)
            .padding(.horizontal, 20)
        }
    }
}
