import SwiftUI

struct QbittorrentHomeCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(Localizer.self) private var localizer

    @State private var totalTorrents: Int = 0
    @State private var downloadingCount: Int = 0
    @State private var seedingCount: Int = 0
    @State private var pausedCount: Int = 0
    @State private var downloadSpeed: Int64 = 0
    @State private var uploadSpeed: Int64 = 0
    @State private var hasInstance: Bool = false
    @State private var fetchFailed: Bool = false
    @State private var instanceId: UUID?

    var body: some View {
        Group {
            if hasInstance, let instanceId {
                NavigationLink(value: HomeServiceRoute(type: .qbittorrent, instanceId: instanceId)) {
                    cardContent
                }
                .buttonStyle(TilePressButtonStyle())
            } else {
                cardContent
            }
        }
        .task(id: coordinator.refreshTrigger) { await fetchData() }
    }

    private var cardContent: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.info)
                Text(localizer.t.serviceQbittorrent).font(.subheadline.weight(.semibold))
                Spacer()
                if hasInstance {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            if hasInstance, fetchFailed {
                statPlaceholder(localizer.t.statusUnreachable)
            } else if hasInstance, totalTorrents > 0 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    stat(localizer.t.homeQbitTorrents, "\(totalTorrents)")
                    stat(localizer.t.homeQbitDownloading, "\(downloadingCount)", accent: AppTheme.info)
                    stat(localizer.t.homeQbitSeeding, "\(seedingCount)", accent: AppTheme.running)
                    stat(localizer.t.homeQbitPaused, "\(pausedCount)")
                }
                HStack(spacing: 12) {
                    Text(String(format: localizer.t.homeQbitDownloadSpeed, Formatters.formatBytes(Double(downloadSpeed)) + "/s"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.info)
                    Text(String(format: localizer.t.homeQbitUploadSpeed, Formatters.formatBytes(Double(uploadSpeed)) + "/s"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.running)
                    Spacer(minLength: 0)
                }
            } else if hasInstance {
                statPlaceholder(localizer.t.homeQbitNoActive)
            } else {
                statPlaceholder(localizer.t.launcherNotConfigured)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassCard()
    }

    private func stat(_ label: String, _ value: String, accent: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.body, design: .rounded).weight(.bold).monospacedDigit()).foregroundStyle(accent ?? .primary)
            Text(label).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statPlaceholder(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
    }

    private func fetchData() async {
        guard let instance = servicesStore.preferredInstance(for: .qbittorrent) else {
            hasInstance = false
            instanceId = nil
            fetchFailed = false
            return
        }
        hasInstance = true
        instanceId = instance.id
        guard let client = await servicesStore.qbittorrentClient(instanceId: instance.id) else {
            fetchFailed = true
            return
        }
        do {
            async let torrentsTask = client.getTorrents()
            async let transferTask = client.getTransferInfo()
            let torrents = try await torrentsTask
            let transfer = try? await transferTask
            totalTorrents = torrents.count
            downloadingCount = torrents.filter { $0.isDownloading && !$0.isPaused }.count
            seedingCount = torrents.filter { $0.isUploading && !$0.isPaused }.count
            pausedCount = torrents.filter { $0.isPaused && !$0.isChecking }.count
            downloadSpeed = transfer?.dl_info_speed ?? torrents.reduce(0) { $0 + $1.dlspeed }
            uploadSpeed = transfer?.up_info_speed ?? torrents.reduce(0) { $0 + $1.upspeed }
            fetchFailed = false
        } catch {
            fetchFailed = true
        }
    }
}
