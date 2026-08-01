import SwiftUI

struct HeroCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(Localizer.self) private var localizer

    @State private var isOnline: Bool = false
    @State private var hostname: String = "--"
    @State private var uptime: String = "--"
    @State private var cpuPercent: Double = 0
    @State private var memPercent: Double = 0
    @State private var diskPercent: Double = 0
    @State private var netUp: Double = 0
    @State private var netDown: Double = 0
    @State private var diskTemps: [DiskTempInfo] = []

    private struct DiskTempInfo: Identifiable { let id = UUID(); let name: String; let celsius: Double }

    private func gaugeColor(_ pct: Double) -> Color { pct > 85 ? AppTheme.danger : pct > 70 ? AppTheme.warning : AppTheme.info }
    private func tempColor(_ c: Double) -> Color { c > 55 ? AppTheme.danger : c > 45 ? AppTheme.warning : AppTheme.running }

    private var beszelRoute: HomeServiceRoute? {
        guard let inst = servicesStore.preferredInstance(for: .beszel) else { return nil }
        return HomeServiceRoute(type: .beszel, instanceId: inst.id)
    }

    var body: some View {
        Group {
            if let route = beszelRoute {
                NavigationLink(value: route) {
                    heroContent
                }
                .buttonStyle(TilePressButtonStyle())
            } else {
                heroContent
            }
        }
        .task(id: coordinator.refreshTrigger) { await fetchData() }
    }

    private var heroContent: some View {
        VStack(spacing: 12) {
            header
            if isOnline {
                gaugeRings
                networkRow
                if !diskTemps.isEmpty { diskTempRow }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassCard()
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack").font(.title3).foregroundStyle(isOnline ? AppTheme.info : AppTheme.textMuted)
            VStack(alignment: .leading, spacing: 1) {
                Text(hostname).font(.subheadline.weight(.bold)).lineLimit(1)
                HStack(spacing: 4) {
                    Circle().fill(isOnline ? AppTheme.running : AppTheme.stopped).frame(width: 5, height: 5)
                    Text(isOnline ? localizer.t.portainerOnline : localizer.t.portainerOffline).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isOnline { Text(uptime).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary) }
            if beszelRoute != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var gaugeRings: some View {
        HStack(spacing: 0) {
            ring("CPU", cpuPercent, gaugeColor(cpuPercent))
            Spacer()
            ring("MEM", memPercent, gaugeColor(memPercent))
            Spacer()
            ring("DSK", diskPercent, gaugeColor(diskPercent))
        }
    }

    private func ring(_ label: String, _ pct: Double, _ color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(.white.opacity(0.06), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(max(pct, 0) / 100, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pct)
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", pct)).font(.system(.body, design: .rounded).weight(.bold))
                    Text("%").font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 56, height: 56)
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
        }
    }

    private var networkRow: some View {
        HStack {
            Spacer()
            Label(title: { Text(fmtNet(netDown)).font(.caption2.monospacedDigit()) }, icon: { Image(systemName: "arrow.down").font(.caption2).foregroundStyle(AppTheme.info) })
            Spacer()
            Label(title: { Text(fmtNet(netUp)).font(.caption2.monospacedDigit()) }, icon: { Image(systemName: "arrow.up").font(.caption2).foregroundStyle(AppTheme.running) })
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var diskTempRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(diskTemps) { d in
                    HStack(spacing: 3) {
                        Circle().fill(tempColor(d.celsius)).frame(width: 4, height: 4)
                        Text("\(Int(d.celsius))°").font(.caption2.monospacedDigit().weight(.semibold))
                        Text(d.name).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }

    private func fmtNet(_ bps: Double) -> String {
        if bps >= 1_048_576 { return String(format: "%.1f MB/s", bps / 1_048_576) }
        if bps >= 1024 { return String(format: "%.0f KB/s", bps / 1024) }
        if bps > 0 { return String(format: "%.0f B/s", bps) }
        return "—"
    }

    private func fetchData() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { isOnline = false; return }
        do {
            let resp = try await client.getSystems()
            guard let primary = resp.items.first else { isOnline = false; return }
            isOnline = primary.isOnline
            hostname = primary.info?.h ?? primary.name
            let s = primary.info?.uValue ?? 0; uptime = s > 0 ? fmtUptime(s) : "--"
            if primary.isOnline, let info = primary.info {
                cpuPercent = info.cpuValue; memPercent = info.mpValue; diskPercent = info.dpValue
            }
            if let records = try? await client.getSystemRecords(systemId: primary.id, limit: 1),
               let stats = records.items.first?.stats {
                netUp = stats.bandwidthUpBytesPerSec ?? 0; netDown = stats.bandwidthDownBytesPerSec ?? 0
            }
            diskTemps = ((try? await client.getSmartDevices(systemId: primary.id)) ?? []).compactMap {
                guard let t = $0.temp, t > 0 else { return nil }; return DiskTempInfo(name: $0.device, celsius: t)
            }
        } catch { isOnline = false }
    }

    private func fmtUptime(_ s: Double) -> String {
        let t = Int(s); let d = t/86400; let h = (t%86400)/3600; let m = (t%3600)/60
        if d > 0 { return "\(d)d \(h)h \(m)m" }; if h > 0 { return "\(h)h \(m)m" }; return "\(m)m"
    }
}
