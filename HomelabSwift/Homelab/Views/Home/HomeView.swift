import SwiftUI

struct HomeView: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(Localizer.self) private var localizer

    @State private var coordinator = DashboardRefreshCoordinator()
    @State private var systemStore = DashboardSystemStore()
    @State private var showLogin: ServiceType? = nil
    @State private var showingCardOrder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    topBar

                    dashboardCards

                    serviceSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AppTheme.premiumGradient())
            .navigationBarHidden(true)
            .sheet(item: $showLogin) { type in
                ServiceLoginView(serviceType: type)
            }
            .sheet(isPresented: $showingCardOrder) {
                DashboardCardOrderSheet()
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

    private var topBar: some View {
        HStack(spacing: 12) {
            networkAccessToggle
            Spacer(minLength: 8)
            Button {
                HapticManager.light()
                showingCardOrder = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    private var networkAccessToggle: some View {
        HStack(spacing: 0) {
            networkModeButton(
                mode: .local,
                title: localizer.t.networkAccessLocal,
                systemImage: "house.fill"
            )
            networkModeButton(
                mode: .remote,
                title: localizer.t.networkAccessRemote,
                systemImage: "network"
            )
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localizer.t.networkAccessMode)
    }

    private func networkModeButton(mode: NetworkAccessMode, title: String, systemImage: String) -> some View {
        let isSelected = settingsStore.networkAccessMode == mode
        return Button {
            guard settingsStore.networkAccessMode != mode else { return }
            HapticManager.light()
            settingsStore.networkAccessMode = mode
            Task {
                await servicesStore.checkAllReachability(force: true)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.surface)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Overview cards driven by `settingsStore.dashboardCardOrder` (not a hard-coded layout).
    private var dashboardCards: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(settingsStore.dashboardCardOrder) { id in
                dashboardCard(for: id)
                    .gridCellColumns(id.spansFullWidth ? 2 : 1)
            }
        }
    }

    @ViewBuilder
    private func dashboardCard(for id: DashboardCardID) -> some View {
        switch id {
        case .hero:
            HeroCard()
        case .docker:
            DockerOverviewCard()
        case .qbittorrent:
            QbittorrentHomeCard()
        }
    }

    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localizer.t.launcherServices)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.top, 4)

            ServiceTileGrid(selectedNewServiceType: $showLogin)
        }
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
        case .nginxProxyManager:  NpmDashboard(instanceId: route.instanceId)
        case .pangolin:           PangolinDashboard(instanceId: route.instanceId)
        case .patchmon:           PatchmonDashboard(instanceId: route.instanceId)
        case .jellystat:          JellystatDashboard(instanceId: route.instanceId)
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
        case .cloudsaver:        CloudSaverDashboard(instanceId: route.instanceId)
        case .jellyseerr, .prowlarr, .bazarr, .gluetun, .flaresolverr:
                                 GenericMediaDashboard(serviceType: route.type, instanceId: route.instanceId)
        }
    }
}

struct HomeServiceRoute: Hashable {
    let type: ServiceType
    let instanceId: UUID
}

private struct DashboardCardOrderSheet: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(Localizer.self) private var localizer
    @Environment(\.dismiss) private var dismiss

    /// All configured home-eligible services (including hidden), for reorder + visibility.
    private var orderedHomeServices: [ServiceType] {
        let configured = Set(
            ServiceType.homeServices.filter { servicesStore.preferredInstance(for: $0) != nil }
        )
        return settingsStore.orderedHomeServices(configured: configured, includeHidden: true)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(settingsStore.dashboardCardOrder) { id in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: id))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.info)
                                .frame(width: 28, height: 28)
                            Text(title(for: id))
                                .font(.body.weight(.medium))
                        }
                    }
                    .onMove { source, destination in
                        settingsStore.moveDashboardCard(from: source, to: destination)
                        HapticManager.light()
                    }
                } header: {
                    Text(localizer.t.homeReorderCards)
                } footer: {
                    Text(localizer.t.homeReorderCardsHint)
                }

                Section {
                    if orderedHomeServices.isEmpty {
                        Text(localizer.t.homeNoServices)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(orderedHomeServices, id: \.rawValue) { type in
                            let isHidden = settingsStore.isServiceHidden(type)
                            HStack(spacing: 12) {
                                ServiceIconView(type: type, size: 22)
                                    .frame(width: 28, height: 28)
                                    .opacity(isHidden ? 0.45 : 1)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(isHidden ? .secondary : .primary)
                                    if isHidden {
                                        Text(localizer.t.homeHiddenBadge)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                Button {
                                    settingsStore.toggleServiceVisibility(type)
                                    HapticManager.light()
                                } label: {
                                    Image(systemName: isHidden ? "eye.slash" : "eye")
                                        .foregroundStyle(isHidden ? AppTheme.textMuted : AppTheme.info)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(
                                    isHidden
                                        ? localizer.t.settingsShowServiceGeneric
                                        : localizer.t.settingsHideServiceGeneric
                                )
                            }
                        }
                        .onMove { source, destination in
                            settingsStore.moveServices(
                                from: source,
                                to: destination,
                                within: ServiceType.homeServices
                            )
                            HapticManager.light()
                        }
                    }
                } header: {
                    Text(localizer.t.homeReorderServices)
                } footer: {
                    Text(localizer.t.homeReorderServicesHint)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(localizer.t.homeReorderCards)
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.t.done) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(localizer.t.homeResetCardOrder) {
                            settingsStore.resetDashboardCardOrder()
                            HapticManager.light()
                        }
                        Button(localizer.t.homeReorderServices) {
                            settingsStore.resetHomeServiceOrder()
                            HapticManager.light()
                        }
                        Button(localizer.t.homeResetLayout) {
                            settingsStore.resetHomeLayout()
                            HapticManager.light()
                        }
                    } label: {
                        Text(localizer.t.homeResetCardOrder)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func title(for id: DashboardCardID) -> String {
        switch id {
        case .hero: return localizer.t.homeHeroCard
        case .docker: return localizer.t.homeDockerLabel
        case .qbittorrent: return localizer.t.serviceQbittorrent
        }
    }

    private func icon(for id: DashboardCardID) -> String {
        switch id {
        case .hero: return "server.rack"
        case .docker: return "shippingbox"
        case .qbittorrent: return "arrow.down.circle"
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
