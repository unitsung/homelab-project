import SwiftUI

struct QbittorrentHomeCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var totalTorrents: Int = 0
    @State private var downloadingCount: Int = 0
    @State private var seedingCount: Int = 0
    @State private var pausedCount: Int = 0
    @State private var hasInstance: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.info)
                Text("qBittorrent").font(.subheadline.weight(.semibold))
                Spacer()
            }
            if hasInstance, totalTorrents > 0 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    stat("种子", "\(totalTorrents)")
                    stat("下载中", "\(downloadingCount)", accent: AppTheme.info)
                    stat("做种", "\(seedingCount)", accent: AppTheme.running)
                    stat("暂停", "\(pausedCount)")
                }
            } else if hasInstance {
                statPlaceholder("无活动种子")
            } else {
                statPlaceholder("未配置")
            }
        }
        .padding(16)
        .glassCard()
        .task(id: coordinator.refreshTrigger) { await fetchData() }
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
        guard let instance = servicesStore.preferredInstance(for: .qbittorrent) else { hasInstance = false; return }
        hasInstance = true
        guard let client = await servicesStore.qbittorrentClient(instanceId: instance.id) else { return }
        do {
            let torrents = try await client.getTorrents()
            totalTorrents = torrents.count
            downloadingCount = torrents.filter { $0.isDownloading && !$0.isPaused }.count
            seedingCount = torrents.filter { $0.isUploading && !$0.isPaused }.count
            pausedCount = torrents.filter { $0.isPaused && !$0.isChecking }.count
        } catch {}
    }
}
