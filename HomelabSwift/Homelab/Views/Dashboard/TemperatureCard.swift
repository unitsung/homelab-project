import SwiftUI

struct TemperatureCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore

    @State private var sensors: [(name: String, celsius: Double)] = []

    var body: some View {
        DashboardCard(title: "温度", icon: "thermometer.medium") {
            if sensors.isEmpty {
                Text("无数据")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ForEach(sensors, id: \.name) { sensor in
                    HStack {
                        Text(sensor.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Gauge(value: sensor.celsius, in: 0...100) {}
                            .gaugeStyle(.accessoryLinearCapacity)
                            .tint(temperatureColor(sensor.celsius))
                            .frame(width: 60)
                        Text("\(Int(sensor.celsius))°C")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchTemperatures()
        }
    }

    private func temperatureColor(_ celsius: Double) -> Color {
        if celsius > 80 { return AppTheme.stopped }
        if celsius > 60 { return AppTheme.warning }
        return AppTheme.running
    }

    private func fetchTemperatures() async {
        await systemStore.refresh(servicesStore: servicesStore)
        guard let systemId = systemStore.firstSystemId,
              let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let recordsResponse = try await client.getSystemRecords(systemId: systemId, limit: 1)
            guard let latestRecord = recordsResponse.items.first?.stats else { return }
            let tempMap = latestRecord.temperatureSensors
            sensors = tempMap.map { (name: $0.key, celsius: $0.value) }
                .filter { $0.celsius > 0 }
                .sorted { $0.celsius > $1.celsius }
        } catch {}
    }
}
