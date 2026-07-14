---
comet_change: home-dashboard-redesign
role: technical-design
canonical_spec: openspec
---

# Home Dashboard 首页重构技术设计

## 概述

将 Homelab iOS 首页从服务图标网格重构为现代化 NAS Dashboard，聚合 Beszel 系统监控数据和 Arcane Docker 管理数据，使用 Swift Charts 展示实时资源图表。

## 架构

```
HomeView (ScrollView + LazyVGrid 2-col)
├── DashboardRefreshCoordinator (@Environment)
│   ├── timer: 10s 轮询
│   ├── refreshPublisher: Combine
│   └── isRefreshing: Bool
│
├── SystemHealthCard (.task { beszelClient.getFirstSystem() })
│   └── OMV 在线状态、主机名、运行时间
│
├── CPUMonitorCard (.task { beszelClient.getSystemRecords() })
│   └── Swift Charts Gauge (环形仪表) + 百分比
│
├── MemoryMonitorCard (.task { beszelClient.getSystemRecords() })
│   └── Swift Charts BarMark (堆叠条形) + GB
│
├── DiskMonitorCard (.task { beszelClient.getSystemRecords() })
│   └── Swift Charts SectorMark (甜甜圈) + 卷信息
│
├── TemperatureCard (.task { beszelClient.getSystemRecords() })
│   └── 自定义温度计 View + °C
│
├── DockerOverviewCard (.task { arcaneClient.getContainers() })
│   └── 计数徽章 + ScrollView(.horizontal) 状态列表
│
└── ServiceEntryCard (本地数据)
    └── 5 个核心服务 icon + 导航
```

## 组件设计

### DashboardRefreshCoordinator

```swift
@Observable
final class DashboardRefreshCoordinator {
    var refreshTrigger = UUID()
    private var timer: Timer?

    func start() { timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
        self.refreshTrigger = UUID()
    }}
    func stop() { timer?.invalidate() }
}
```

注入 `@Environment`，各卡片通过 `.id(refreshTrigger)` 或 `.task(id: refreshTrigger)` 响应刷新。

### 卡片基模版

```swift
struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

### CPUMonitorCard

```swift
struct CPUMonitorCard: View {
    @Environment(DashboardRefreshCoordinator.self) var coordinator
    @State private var cpuPercent: Double = 0

    var body: some View {
        DashboardCard(title: "CPU", icon: "cpu") {
            Gauge(value: cpuPercent, in: 0...100) {
                Text("\(Int(cpuPercent))%")
            } currentValueLabel: { Text("CPU") }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(cpuPercent > 80 ? .red : cpuPercent > 60 ? .yellow : .green)
        }
        .task(id: coordinator.refreshTrigger) {
            cpuPercent = await fetchCPU()
        }
    }
}
```

### MemoryMonitorCard

```swift
struct MemoryMonitorCard: View {
    @State private var memory: MemoryInfo?

    var body: some View {
        DashboardCard(title: "内存", icon: "memorychip") {
            Chart {
                BarMark(x: .value("", "已用"), y: .value("GB", memory?.usedGB ?? 0))
                    .foregroundStyle(.blue)
                BarMark(x: .value("", "缓存"), y: .value("GB", memory?.cachedGB ?? 0))
                    .foregroundStyle(.green)
                BarMark(x: .value("", "空闲"), y: .value("GB", memory?.freeGB ?? 0))
                    .foregroundStyle(.gray.opacity(0.3))
            }
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(values: .automatic) }
        }
    }
}
```

### DiskMonitorCard

```swift
struct DiskMonitorCard: View {
    @State private var disks: [DiskInfo] = []

    var body: some View {
        DashboardCard(title: "磁盘", icon: "externaldrive") {
            ForEach(disks) { disk in
                Chart {
                    SectorMark(angle: .value("已用", disk.usedGB),
                               innerRadius: .ratio(0.6))
                        .foregroundStyle(.blue)
                    SectorMark(angle: .value("可用", disk.freeGB),
                               innerRadius: .ratio(0.6))
                        .foregroundStyle(.gray.opacity(0.3))
                }
                .frame(height: 60)
            }
        }
    }
}
```

### TemperatureCard

```swift
struct TemperatureCard: View {
    @State private var temperatures: [SensorInfo] = []

    var body: some View {
        DashboardCard(title: "温度", icon: "thermometer.medium") {
            ForEach(temperatures) { sensor in
                HStack {
                    Text(sensor.name).font(.caption)
                    Spacer()
                    Gauge(value: sensor.celsius, in: 0...100) {}
                        .gaugeStyle(.accessoryLinearCapacity)
                        .frame(width: 60)
                    Text("\(Int(sensor.celsius))°C")
                }
            }
        }
    }
}
```

### DockerOverviewCard

```swift
struct DockerOverviewCard: View {
    @State private var containers: [ArcaneContainer] = []
    private var runningCount: Int { containers.filter { $0.state == "running" }.count }

    var body: some View {
        DashboardCard(title: "Docker", icon: "shippingbox") {
            HStack {
                Label("\(runningCount)/\(containers.count)", systemImage: "circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                NavigationLink("管理", destination: ArcaneDashboard())
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(containers) { container in
                        ContainerStatusDot(container: container)
                    }
                }
            }
        }
    }
}
```

## ArcaneAPIClient 设计

```swift
actor ArcaneAPIClient {
    private let baseURL: URL
    private var apiKey: String?
    private var jwtToken: String?

    // 容器操作
    func getContainers() async throws -> [ArcaneContainer]
    func getContainer(id: String) async throws -> ArcaneContainerDetail
    func getContainerStats(id: String) async throws -> ArcaneContainerStats
    func getContainerLogs(id: String, tail: Int) async throws -> String
    func containerAction(id: String, action: ContainerAction) async throws

    // 认证
    func login(username: String, password: String) async throws
    func setAPIKey(_ key: String)

    enum ContainerAction: String {
        case start, stop, restart, kill, pause, unpause
    }
}
```

## 数据模型

```swift
struct ArcaneContainer: Identifiable, Codable {
    let id: String
    let name: String
    let image: String
    let state: String        // "running", "exited", etc.
    let status: String
    let ports: [PortMapping]?
}

struct ArcaneContainerStats: Codable {
    let cpuPercent: Double
    let memoryUsage: Int64
    let memoryLimit: Int64
    let networkRx: Int64
    let networkTx: Int64
}

struct ArcaneContainerDetail: Codable {
    let container: ArcaneContainer
    let stats: ArcaneContainerStats?
    let logs: String?
}
```

## Dashboard 布局

```
┌──────────────────────┐
│  🟢 系统正常 · 7d 3h  │  ← SystemHealthCard (full width)
├──────────────────────┤
│  [CPU ◉45%] │ [内存 ▊]│  ← 2-col grid
├──────────────────────┤
│  [磁盘 ◔]   │ [温度 🌡]│
├──────────────────────┤
│  🐳 Docker · 12/15   │  ← DockerOverviewCard (full width)
│  ⬤⬤⬤⬤⬤⬤⬤⬤⬤⬤⬤⬤    │
├──────────────────────┤
│ 🏠 服务                │  ← ServiceEntryCard (full width)
│ [truenas] [proxmox]  │
│ [beszel] [openlist]  │
│ [qbittorrent]         │
└──────────────────────┘
```

## 测试策略

- `ArcaneAPIClient` 使用 mock HTTP 响应做接口测试
- 各 Dashboard 卡片使用 `#Preview` + mock 数据做 UI 快照测试
- `DashboardRefreshCoordinator` 测试 timer 生命周期
- Beszel 集成回归测试（确保现有功能不受影响）
