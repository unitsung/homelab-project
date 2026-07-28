import SwiftUI

struct DiskTemperatureCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore
    @Environment(Localizer.self) private var localizer

    @State private var devices: [(name: String, celsius: Double, status: String?)] = []

    private var hottest: Double {
        devices.map(\.celsius).max() ?? 0
    }

    private var tint: Color {
        temperatureColor(hottest)
    }

    private var gaugePercent: Double {
        min(max(hottest, 0), 100)
    }

    var body: some View {
        VStack(spacing: 10) {
            circularGauge(
                percent: gaugePercent,
                centerValue: devices.isEmpty ? "—" : "\(Int(hottest))°",
                label: localizer.t.homeDiskTemperature,
                color: tint
            )

            if devices.isEmpty {
                Text(localizer.t.homeNoSensorData)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 4) {
                    ForEach(devices.prefix(4), id: \.name) { device in
                        HStack {
                            Text(device.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(device.celsius))°C")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(temperatureColor(device.celsius))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard()
        .opacity(devices.isEmpty ? 0.75 : 1)
        .task(id: coordinator.refreshTrigger) {
            await fetch()
        }
    }

    private func circularGauge(percent: Double, centerValue: String, label: String, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(max(percent, 0) / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: percent)
            VStack(spacing: 2) {
                Text(centerValue)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: 80, height: 80)
    }

    private func temperatureColor(_ celsius: Double) -> Color {
        if celsius > 55 { return AppTheme.stopped }
        if celsius > 45 { return AppTheme.warning }
        return AppTheme.running
    }

    private func fetch() async {
        await systemStore.refresh(servicesStore: servicesStore)
        guard let systemId = systemStore.firstSystemId,
              let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else {
            devices = []
            return
        }

        // Prefer S.M.A.R.T. devices (real disk temperatures).
        if let smart = try? await client.getSmartDevices(systemId: systemId) {
            let mapped = smart.compactMap { device -> (name: String, celsius: Double, status: String?)? in
                guard let temp = device.temperatureCelsius, temp > 0 else { return nil }
                return (name: device.device, celsius: temp, status: device.status)
            }
            .sorted { $0.celsius > $1.celsius }
            if !mapped.isEmpty {
                devices = mapped
                return
            }
        }

        // Fallback: temperature sensors filtered for disks.
        if let records = try? await client.getSystemRecords(systemId: systemId, limit: 1),
           let latest = records.items.first?.stats {
            devices = DiskTemperatureSensorFilter.diskSensors(from: latest.temperatureSensors)
                .map { (name: $0.name, celsius: $0.celsius, status: nil) }
        } else {
            devices = []
        }
    }
}
