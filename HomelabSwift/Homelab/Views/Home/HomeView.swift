import SwiftUI

struct HomeView: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(Localizer.self) private var localizer

    @State private var coordinator = DashboardRefreshCoordinator()
    @State private var systemStore = DashboardSystemStore()
    @State private var showLogin: ServiceType? = nil
    @State private var showingServiceOrder = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    SystemHealthCard()
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        CPUMonitorCard()
                        MemoryMonitorCard()
                        DiskMonitorCard()
                        TemperatureCard()
                    }
                    .padding(.horizontal, 16)

                    DockerOverviewCard()
                        .padding(.horizontal, 16)

                    ServiceEntryCard()
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
            .background(AppTheme.background)
            .navigationBarHidden(true)
            .sheet(item: $showLogin) { type in
                ServiceLoginView(serviceType: type)
            }
            .sheet(isPresented: $showingServiceOrder) {
                ServiceOrderSheet()
            }
            .navigationDestination(for: HomeServiceRoute.self) { route in
                serviceDestination(for: route)
            }
        }
        .environment(coordinator)
        .environment(systemStore)
        .onAppear { coordinator.start() }
        .onDisappear { coordinator.stop() }
    }

    private var headerSection: some View {
        HStack {
            Text(localizer.t.launcherTitle)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                HapticManager.light()
                showingServiceOrder = true
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizer.t.homeReorderServices)
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func serviceDestination(for route: HomeServiceRoute) -> some View {
        switch route.type {
        case .portainer:         PortainerDashboard(instanceId: route.instanceId)
        case .pihole:            PiHoleDashboard(instanceId: route.instanceId)
        case .adguardHome:       AdGuardHomeDashboard(instanceId: route.instanceId)
        case .technitium:        TechnitiumDashboard(instanceId: route.instanceId)
        case .beszel:            BeszelDashboard(instanceId: route.instanceId)
        case .healthchecks:      HealthchecksDashboard(instanceId: route.instanceId)
        case .linuxUpdate:            LinuxUpdateDashboard(instanceId: route.instanceId)
        case .dockhand:               DockhandDashboard(instanceId: route.instanceId)
        case .dockmon:                DockmonDashboard(instanceId: route.instanceId)
        case .komodo:                 KomodoDashboard(instanceId: route.instanceId)
        case .maltrail:               MaltrailDashboard(instanceId: route.instanceId)
        case .uptimeKuma:             UptimeKumaDashboard(instanceId: route.instanceId)
        case .craftyController:       CraftyDashboard(instanceId: route.instanceId)
        case .unifiNetwork:           UniFiDashboard(instanceId: route.instanceId)
        case .gitea:             GiteaDashboard(instanceId: route.instanceId)
        case .nginxProxyManager: NpmDashboard(instanceId: route.instanceId)
        case .pangolin:          PangolinDashboard(instanceId: route.instanceId)
        case .patchmon:          PatchmonDashboard(instanceId: route.instanceId)
        case .jellystat:         JellystatDashboard(instanceId: route.instanceId)
        case .plex:              PlexDashboard(instanceId: route.instanceId)
        case .qbittorrent:       QbittorrentDashboard(instanceId: route.instanceId)
        case .radarr:            RadarrDashboard(instanceId: route.instanceId)
        case .sonarr:            SonarrDashboard(instanceId: route.instanceId)
        case .lidarr:            LidarrDashboard(instanceId: route.instanceId)
        case .wakapi:            WakapiDashboard(instanceId: route.instanceId)
        case .proxmox:           ProxmoxDashboard(instanceId: route.instanceId)
        case .truenas:           TrueNASDashboard(instanceId: route.instanceId)
        case .pterodactyl:       PterodactylDashboard(instanceId: route.instanceId)
        case .calagopus:         CalagopusDashboard(instanceId: route.instanceId)
        case .openlist:          OpenListFileBrowserView(instanceId: route.instanceId)
        case .arcane:            ArcaneDashboard(instanceId: route.instanceId)
        case .jellyseerr, .prowlarr, .bazarr, .gluetun, .flaresolverr:
                                 GenericMediaDashboard(serviceType: route.type, instanceId: route.instanceId)
        }
    }
}

struct HomeServiceRoute: Hashable {
    let type: ServiceType
    let instanceId: UUID
}

private struct ServiceOrderSheet: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(Localizer.self) private var localizer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(settingsStore.serviceOrder.filter { ServiceType.homeServices.contains($0) }) { type in
                    let isHidden = settingsStore.isServiceHidden(type)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.displayName)
                                .font(.body.weight(.semibold))
                            if isHidden {
                                Text(localizer.t.settingsHiddenBadge)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                settingsStore.toggleServiceVisibility(type)
                                HapticManager.light()
                            } label: {
                                Image(systemName: isHidden ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(isHidden ? localizer.t.settingsShowServiceGeneric : localizer.t.settingsHideServiceGeneric)

                            Button {
                                settingsStore.moveService(type, offset: -1, within: ServiceType.homeServices)
                                HapticManager.light()
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!settingsStore.canMoveService(type, offset: -1, within: ServiceType.homeServices))
                            .accessibilityLabel(localizer.t.settingsMoveUp)

                            Button {
                                settingsStore.moveService(type, offset: 1, within: ServiceType.homeServices)
                                HapticManager.light()
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!settingsStore.canMoveService(type, offset: 1, within: ServiceType.homeServices))
                            .accessibilityLabel(localizer.t.settingsMoveDown)
                        }
                    }
                }
            }
            .navigationTitle(localizer.t.homeReorderServices)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.done) { dismiss() }
                }
            }
        }
    }
}

struct ServiceIconView: View {
    let type: ServiceType
    let size: CGFloat

    private var candidates: [URL] { type.iconCandidates }
    private var localAssetName: String { type.localIconAssetName }

    var body: some View {
        Group {
            if type == .truenas, let primary = candidates.first {
                primaryIconView(primary)
            } else if let local = UIImage(named: localAssetName) {
                Image(uiImage: local)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                if let primary = candidates.first {
                    primaryIconView(primary)
                } else {
                    fallbackView
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func primaryIconView(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            case .failure:
                if type == .truenas {
                    Color.clear
                } else if candidates.count > 1 {
                    secondaryIconView
                } else {
                    fallbackView
                }
            case .empty:
                if type == .truenas {
                    Color.clear
                } else {
                    fallbackView
                }
            @unknown default:
                fallbackView
            }
        }
        .id(url.absoluteString)
    }

    @ViewBuilder
    private var secondaryIconView: some View {
        if candidates.count > 1 {
            AsyncImage(url: candidates[1]) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                case .failure:
                    fallbackView
                case .empty:
                    fallbackView
                @unknown default:
                    fallbackView
                }
            }
            .id(candidates[1].absoluteString)
        } else {
            fallbackView
        }
    }

    private var fallbackView: some View {
        Image(systemName: type.symbolName)
            .font(.system(size: size * 0.6))
            .foregroundStyle(type.colors.primary)
    }
}
