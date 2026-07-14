---
change: home-dashboard-redesign
design-doc: docs/superpowers/specs/2026-07-14-home-dashboard-redesign-design.md
base-ref: c137cbaaead4d7fdde9489a7b4941a10cff135d0
archived-with: 2026-07-14-home-dashboard-redesign
---

# Home Dashboard 首页重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Homelab iOS 首页从服务图标网格重构为 Dashboard 卡片流，聚合 Beszel 系统监控数据和 Arcane Docker 管理数据。

**Architecture:** 新增 `ArcaneAPIClient` actor（API Key + JWT 双模式认证），创建 7 张 Dashboard 卡片组件（SystemHealthCard 至 ServiceEntryCard），由 `DashboardRefreshCoordinator` 统一 10s 轮询，最后重构 `HomeView` 为 ScrollView + LazyVGrid 2-col 卡片流布局。

**Tech Stack:** SwiftUI (iOS 26), Swift Charts, Combine Timer, Observation framework (@Observable), actor-based API client pattern, XCTest.

## Global Constraints

- 仅修改 iOS 端（HomelabSwift/），Android 端不受影响
- 部署目标 iOS 26，使用原生 `.glassEffect()` 和 Swift Charts
- 所有 API client 使用 `actor` 模式，继承自现有 `BaseNetworkEngine` 组合模式
- 所有 ViewModel/Coordinator 使用 `@Observable`（非 `ObservableObject`）
- `ServiceType.arcane` 必须增加 `displayName`、`symbolName`、`iconUrl`、`colors`、`localizedDescription`（含中英文翻译）
- Arcane 认证支持 API Key（`instance.apiKey`）和 JWT 双模式
- Beszel 数据经现有 `BeszelAPIClient` 获取，不新建客户端
- `ServiceEntryCard` 入口保持现有 `homeServices: [.truenas, .openlist, .proxmox, .beszel, .portainer]` 列表
- 旧 LazyVGrid 服务网格和相关 `ServiceGridEntry`/`ServiceCardContent`/`OverviewStripModel` 需完全移除

---

### Task 1: Arcane 数据模型

**Files:**
- Create: `HomelabSwift/Homelab/Models/Arcane/ArcaneModels.swift`

**Interfaces:**
- Produces: `ArcaneContainer` (Identifiable, Codable), `ArcaneContainerStats` (Codable), `ArcaneContainerDetail` (Codable), `ContainerAction` (String enum: start/stop/restart/kill/pause/unpause)

- [x] **Step 1: 创建 ArcaneModels.swift**

```swift
import Foundation

struct ArcaneContainer: Identifiable, Codable {
    let id: String
    let name: String
    let image: String
    let state: String
    let status: String
    let ports: [ArcanePortMapping]?

    var isRunning: Bool { state == "running" }

    struct ArcanePortMapping: Codable {
        let ip: String?
        let privatePort: Int?
        let publicPort: Int?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case ip = "IP", privatePort = "PrivatePort", publicPort = "PublicPort", type = "Type"
        }
    }
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

    struct ContainerModel: Codable {
        let container: ArcaneContainer
    }
}

enum ContainerAction: String, Codable {
    case start, stop, restart, kill, pause, unpause
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Models/Arcane/ArcaneModels.swift
git commit -m "feat: add Arcane data models (Container, Stats, ContainerAction)"
```

---

Task 2: ServiceType.arcane 扩展 ✅

**Files:**
- Modify: `HomelabSwift/Homelab/Models/ServiceType.swift`
- Modify: `HomelabSwift/Homelab/Localization/Translations.swift`
- Modify: `HomelabSwift/Homelab/Localization/Translations+Chinese.swift`
- Modify: `HomelabSwift/Homelab/Localization/Translations+English.swift`

**Interfaces:**
- Produces: `ServiceType.arcane` case with displayName "Arcane", symbolName "shippingbox.fill", colors (primary: #F97316 orange), iconUrl, localizedDescription

- [x] **Step 1: 在 Translations.swift 中添加翻译 key**

在 `Translations.swift` 中添加两个新 property：

```swift
var serviceArcaneDesc: String { "" }
```

在 `Translations+Chinese.swift` 中添加：

```swift
var serviceArcaneDesc: String { "Docker 容器管理" }
```

在 `Translations+English.swift` 中添加：

```swift
var serviceArcaneDesc: String { "Docker Container Management" }
```

- [x] **Step 2: 在 ServiceType.swift 中添加 .arcane case**

将 `.arcane` case 添加到 `ServiceType` enum 中（在 `.openlist` 之后）：

```swift
case arcane
```

- [x] **Step 3: 在 ServiceType.swift 的各计算属性中添加 arcane 分支**

`displayName`:
```swift
case .arcane:             return "Arcane"
```

`symbolName`:
```swift
case .arcane:             return "shippingbox.fill"
```

`iconUrl`:
```swift
case .arcane:             return "https://cdn.jsdelivr.net/gh/selfhst/icons/png/arcane.png"
```

`localIconAssetName`:
```swift
case .arcane:             return "service-arcane"
```

`localizedDescription`:
```swift
case .arcane:             return t.serviceArcaneDesc
```

`colors`:
```swift
case .arcane:             return ServiceColorSet(primary: Color(hex: "#F97316"), dark: Color(hex: "#C2410C"), bg: Color(hex: "#F97316").opacity(0.08))
```

`iconCandidates` slug:
```swift
case .arcane:             slug = "arcane"
```

`fromStoredRawValue` 规范化:
```swift
case "arcane":
    return .arcane
```

- [x] **Step 4: 在 ServicesStore.swift 中为 arcane 添加 switch case 桩代码**

在 `removeClient` 和 `checkReachability` 的 switch 中添加：
```swift
case .arcane:
    break
```

在 `configureClient` 的 switch 中添加：
```swift
case .arcane:
    break
```

(后续 Task 会替换为完整实现)

- [x] **Step 5: Commit**

```bash
git add HomelabSwift/Homelab/Models/ServiceType.swift HomelabSwift/Homelab/Localization/Translations.swift HomelabSwift/Homelab/Localization/Translations+Chinese.swift HomelabSwift/Homelab/Localization/Translations+English.swift HomelabSwift/Homelab/Stores/ServicesStore.swift
git commit -m "feat: add ServiceType.arcane with displayName, icon, colors, and localization"
```

---

### Task 3: ArcaneAPIClient

**Files:**
- Create: `HomelabSwift/Homelab/Networking/Arcane/ArcaneAPIClient.swift`

**Interfaces:**
- Consumes: `ArcaneContainer`, `ArcaneContainerStats`, `ArcaneContainerDetail`, `ContainerAction` from Task 1
- Produces: `actor ArcaneAPIClient` with methods: `configure(...)`, `ping()`, `getContainers() -> [ArcaneContainer]`, `getContainer(id:) -> ArcaneContainer`, `getContainerStats(id:) -> ArcaneContainerStats`, `getContainerLogs(id:tail:) -> String`, `containerAction(id:action:)`, `login(username:password:) async throws`, `setAPIKey(_:)`, `setTokenRefreshCallback(_:)`

- [x] **Step 1: 创建 ArcaneAPIClient.swift**

```swift
import Foundation

actor ArcaneAPIClient {
    private let instanceId: UUID
    private var engine: BaseNetworkEngine
    private var storedAllowSelfSigned = true
    private var baseURL: String = ""
    private var fallbackURL: String = ""
    private var apiKey: String?
    private var jwtToken: String?
    private var username: String?
    private var storedPassword: String?
    private var isRefreshing = false
    private var onTokenRefreshed: (@Sendable (String) -> Void)?

    init(instanceId: UUID) {
        self.instanceId = instanceId
        self.engine = BaseNetworkEngine(serviceType: .arcane, instanceId: instanceId)
    }

    func configure(url: String, apiKey: String?, token: String?, fallbackUrl: String?, username: String?, password: String?, allowSelfSigned: Bool?) {
        self.baseURL = Self.cleanURL(url)
        self.fallbackURL = Self.cleanURL(fallbackUrl ?? "")
        if let apiKey, !apiKey.isEmpty { self.apiKey = apiKey }
        if let token, !token.isEmpty { self.jwtToken = token }
        if let username, !username.isEmpty { self.username = username }
        if let password, !password.isEmpty { self.storedPassword = password }
        if let allowSelfSigned { storedAllowSelfSigned = allowSelfSigned }
        engine = BaseNetworkEngine(serviceType: .arcane, instanceId: self.instanceId, allowSelfSigned: self.storedAllowSelfSigned)
    }

    func setTokenRefreshCallback(_ callback: @escaping @Sendable (String) -> Void) {
        self.onTokenRefreshed = callback
    }

    func setAPIKey(_ key: String) {
        self.apiKey = key.isEmpty ? nil : key
    }

    private func authHeaders() -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let apiKey { headers["X-API-Key"] = apiKey }
        else if let jwtToken { headers["Authorization"] = "Bearer \(jwtToken)" }
        return headers
    }

    private static func cleanURL(_ url: String) -> String {
        url.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    func ping() async -> Bool {
        if baseURL.isEmpty { return false }
        if await engine.pingURL("\(baseURL)/api/health", extraHeaders: authHeaders()) { return true }
        if !fallbackURL.isEmpty {
            return await engine.pingURL("\(fallbackURL)/api/health", extraHeaders: authHeaders())
        }
        return false
    }

    func login(username: String, password: String) async throws {
        let response: LoginResponse = try await engine.request(
            baseURL: baseURL, fallbackURL: fallbackURL,
            path: "/api/auth/login",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(["username": username, "password": password])
        )
        self.jwtToken = response.token
        onTokenRefreshed?(response.token)
    }

    struct LoginResponse: Codable { let token: String }

    private func authenticatedRequest<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        do {
            return try await engine.request(baseURL: baseURL, fallbackURL: fallbackURL, path: path, method: method, headers: authHeaders(), body: body)
        } catch {
            if isAuthError(error), let storedUsername = username, let storedPassword = storedPassword {
                try await login(username: storedUsername, password: storedPassword)
                return try await engine.request(baseURL: baseURL, fallbackURL: fallbackURL, path: path, method: method, headers: authHeaders(), body: body)
            }
            throw error
        }
    }

    private func isAuthError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .httpError(let code, _): return code == 401 || code == 403
        case .unauthorized: return true
        case .bothURLsFailed(let primary, let fallback): return isAuthError(primary) || isAuthError(fallback)
        default: return false
        }
    }

    func getContainers() async throws -> [ArcaneContainer] {
        return try await authenticatedRequest(path: "/api/containers")
    }

    func getContainer(id: String) async throws -> ArcaneContainer {
        return try await authenticatedRequest(path: "/api/containers/\(id)")
    }

    func getContainerStats(id: String) async throws -> ArcaneContainerStats {
        return try await authenticatedRequest(path: "/api/containers/\(id)/stats")
    }

    func getContainerLogs(id: String, tail: Int = 100) async throws -> String {
        return try await engine.requestString(
            baseURL: baseURL, fallbackURL: fallbackURL,
            path: "/api/containers/\(id)/logs?tail=\(tail)",
            headers: authHeaders()
        )
    }

    func containerAction(id: String, action: ContainerAction) async throws {
        let _: EmptyResponse = try await authenticatedRequest(
            path: "/api/containers/\(id)/\(action.rawValue)",
            method: "POST"
        )
    }

    private struct EmptyResponse: Codable {}
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Networking/Arcane/ArcaneAPIClient.swift
git commit -m "feat: implement ArcaneAPIClient (API Key + JWT dual auth, containers CRUD)"
```

---

### Task 4: ServicesStore Arcane 集成

**Files:**
- Modify: `HomelabSwift/Homelab/Stores/ServicesStore.swift`

**Interfaces:**
- Consumes: `ArcaneAPIClient` from Task 3, `ServiceType.arcane` from Task 2
- Produces: `arcaneClient(instanceId:) -> ArcaneAPIClient?` accessible via ServicesStore

- [x] **Step 1: 在 ServiceClientManager 中添加 arcane 客户端管理**

在 `ServiceClientManager` 的 property 区域添加：
```swift
private var arcaneClients: [UUID: ArcaneAPIClient] = [:]
```

添加工厂方法和移除方法：
```swift
func arcaneClient(id: UUID) -> ArcaneAPIClient {
    if let client = arcaneClients[id] { return client }
    let client = ArcaneAPIClient(instanceId: id)
    arcaneClients[id] = client
    return client
}
```

在 `removeClient` switch 中添加：
```swift
case .arcane:
    arcaneClients.removeValue(forKey: id)
```

在 `purgeUnknownClients` 中添加：
```swift
arcaneClients = arcaneClients.filter { knownInstanceIds.contains($0.key) }
```

- [x] **Step 2: 在 ServicesStore 中添加公开访问方法**

```swift
func arcaneClient(instanceId: UUID) async -> ArcaneAPIClient? {
    guard let instance = instancesById[instanceId], instance.type == .arcane else { return nil }
    return clientManager.arcaneClient(id: instance.id)
}
```

- [x] **Step 3: 替换 Step 4 中的 arcane configureClient 桩代码**

在 `configureClient` switch 中替换 `.arcane` case：
```swift
case .arcane:
    let client = clientManager.arcaneClient(id: instance.id)
    await client.configure(
        url: instance.url,
        apiKey: instance.apiKey,
        token: instance.token,
        fallbackUrl: instance.fallbackUrl,
        username: instance.username,
        password: instance.password,
        allowSelfSigned: instance.allowSelfSigned
    )
    let instanceId = instance.id
    await client.setTokenRefreshCallback { [weak self] newToken in
        Task { @MainActor in
            guard let self, var current = self.instancesById[instanceId] else { return }
            current.token = newToken
            self.instancesById[instanceId] = current
            self.persistState()
        }
    }
```

- [x] **Step 4: 替换 checkReachability 中的 arcane 桩**

在 `checkReachability` switch 中替换：
```swift
case .arcane:
    ok = await clientManager.arcaneClient(id: instanceId).ping()
```

- [x] **Step 5: Commit**

```bash
git add HomelabSwift/Homelab/Stores/ServicesStore.swift
git commit -m "feat: integrate ArcaneAPIClient into ServicesStore lifecycle"
```

---

### Task 5: DashboardRefreshCoordinator

**Files:**
- Create: `HomelabSwift/Homelab/Stores/DashboardRefreshCoordinator.swift`

**Interfaces:**
- Produces: `@Observable final class DashboardRefreshCoordinator` with `var refreshTrigger = UUID()`, `func start()`, `func stop()`, `var isRefreshing = false`

- [x] **Step 1: 创建 DashboardRefreshCoordinator.swift**

```swift
import Foundation
import Observation

@Observable
final class DashboardRefreshCoordinator {
    var refreshTrigger = UUID()
    private(set) var isRefreshing = false
    private var timer: Timer?

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isRefreshing = true
                self?.refreshTrigger = UUID()
                self?.isRefreshing = false
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRefreshing = false
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Stores/DashboardRefreshCoordinator.swift
git commit -m "feat: add DashboardRefreshCoordinator for 10s poll cycle"
```

---

### Task 6: DashboardCard 通用卡片组件

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/DashboardCard.swift`

**Interfaces:**
- Produces: `struct DashboardCard<Content: View>: View` with `title: String`, `icon: String`, `@ViewBuilder content: () -> Content`

- [x] **Step 1: 创建 DashboardCard.swift**

```swift
import SwiftUI

struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: AppTheme.cardRadius)
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/DashboardCard.swift
git commit -m "feat: add reusable DashboardCard component with glass effect"
```

---

### Task 7: SystemHealthCard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/SystemHealthCard.swift`

**Interfaces:**
- Consumes: `DashboardRefreshCoordinator` (Task 5), `DashboardCard` (Task 6), `ServicesStore` (existing), `BeszelAPIClient` (existing via servicesStore)
- Produces: `struct SystemHealthCard: View` - 显示 OMV 在线状态、主机名、运行时间

- [x] **Step 1: 创建 SystemHealthCard.swift**

```swift
import SwiftUI

struct SystemHealthCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var isOnline: Bool = false
    @State private var hostname: String = "--"
    @State private var uptime: String = "--"

    var body: some View {
        DashboardCard(title: "系统健康", icon: "heart.circle.fill") {
            HStack(spacing: 12) {
                Circle()
                    .fill(isOnline ? AppTheme.running : AppTheme.stopped)
                    .frame(width: 12, height: 12)
                Text(isOnline ? "在线" : "离线")
                    .font(.title3.bold())
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hostname)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(uptime)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .lineLimit(1)
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchSystemHealth()
        }
    }

    private func fetchSystemHealth() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else {
            isOnline = false
            return
        }
        do {
            let response = try await client.getSystems()
            guard let system = response.items.first else {
                isOnline = false
                return
            }
            isOnline = system.isOnline
            hostname = system.info?.h ?? system.name
            let seconds = system.info?.uValue ?? 0
            uptime = seconds > 0 ? formatUptime(seconds) : "--"
        } catch {
            isOnline = false
        }
    }

    private func formatUptime(_ seconds: Double) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h"
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/SystemHealthCard.swift
git commit -m "feat: add SystemHealthCard showing OMV status, hostname, uptime"
```

---

### Task 8: CPUMonitorCard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/CPUMonitorCard.swift`

**Interfaces:**
- Consumes: `DashboardRefreshCoordinator` (Task 5), `DashboardCard` (Task 6), `ServicesStore`
- Produces: `struct CPUMonitorCard: View` - Swift Charts Gauge 环形百分比

- [x] **Step 1: 创建 CPUMonitorCard.swift**

```swift
import SwiftUI
import Charts

struct CPUMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var cpuPercent: Double = 0

    var body: some View {
        DashboardCard(title: "CPU", icon: "cpu") {
            VStack(spacing: 8) {
                Gauge(value: cpuPercent, in: 0...100) {
                    Text("\(Int(cpuPercent))%")
                        .font(.title2.bold())
                } currentValueLabel: {
                    Text("CPU")
                        .font(.caption2)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(cpuPercent > 80 ? AppTheme.stopped : cpuPercent > 60 ? AppTheme.warning : AppTheme.running)
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchCPU()
        }
    }

    private func fetchCPU() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let response = try await client.getSystems()
            guard let info = response.items.first?.info else { return }
            cpuPercent = info.cpuValue
        } catch {}
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/CPUMonitorCard.swift
git commit -m "feat: add CPUMonitorCard with Swift Charts Gauge"
```

---

### Task 9: MemoryMonitorCard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/MemoryMonitorCard.swift`

**Interfaces:**
- Consumes: `DashboardRefreshCoordinator` (Task 5), `DashboardCard` (Task 6), `ServicesStore`
- Produces: `struct MemoryMonitorCard: View` - Swift Charts BarMark 堆叠条形图

- [x] **Step 1: 创建 MemoryMonitorCard.swift**

```swift
import SwiftUI
import Charts

struct MemoryMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var usedGB: Double = 0
    @State private var cachedGB: Double = 0
    @State private var freeGB: Double = 0
    @State private var totalGB: Double = 0

    var body: some View {
        DashboardCard(title: "内存", icon: "memorychip") {
            VStack(spacing: 8) {
                Chart {
                    BarMark(x: .value("", "已用"), y: .value("GB", usedGB))
                        .foregroundStyle(AppTheme.info)
                    BarMark(x: .value("", "缓存"), y: .value("GB", cachedGB))
                        .foregroundStyle(AppTheme.running)
                    BarMark(x: .value("", "空闲"), y: .value("GB", freeGB))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(values: .automatic) }
                .frame(height: 60)

                Text("\(Int(usedGB)) GB / \(Int(totalGB)) GB")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchMemory()
        }
    }

    private func fetchMemory() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let response = try await client.getSystems()
            guard let info = response.items.first?.info else { return }
            totalGB = info.mtValue
            usedGB = info.mValue
            let cached = max(0, totalGB - usedGB)
            cachedGB = cached * 0.3
            freeGB = cached - cachedGB
        } catch {}
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/MemoryMonitorCard.swift
git commit -m "feat: add MemoryMonitorCard with stacked BarMark chart"
```

---

### Task 10: DiskMonitorCard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/DiskMonitorCard.swift`

**Interfaces:**
- Consumes: `DashboardRefreshCoordinator` (Task 5), `DashboardCard` (Task 6), `ServicesStore`
- Produces: `struct DiskMonitorCard: View` - Swift Charts SectorMark 甜甜圈

- [x] **Step 1: 创建 DiskMonitorCard.swift**

```swift
import SwiftUI
import Charts

struct DiskMonitorCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var diskUsedGB: Double = 0
    @State private var diskFreeGB: Double = 0
    @State private var diskPercent: Double = 0

    var body: some View {
        DashboardCard(title: "磁盘", icon: "externaldrive") {
            VStack(spacing: 8) {
                Chart {
                    SectorMark(angle: .value("已用", diskUsedGB), innerRadius: .ratio(0.6))
                        .foregroundStyle(AppTheme.info)
                    SectorMark(angle: .value("可用", diskFreeGB), innerRadius: .ratio(0.6))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
                .frame(height: 80)

                Text("已用 \(Int(diskPercent))%")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchDisk()
        }
    }

    private func fetchDisk() async {
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let response = try await client.getSystems()
            guard let info = response.items.first?.info else { return }
            diskPercent = info.dpValue
            diskUsedGB = info.duValue > 0 ? info.duValue : info.dValue
            diskFreeGB = max(0, (diskUsedGB / max(diskPercent, 0.1) * 100) - diskUsedGB)
        } catch {}
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/DiskMonitorCard.swift
git commit -m "feat: add DiskMonitorCard with SectorMark donut chart"
```

---

### Task 11: TemperatureCard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/TemperatureCard.swift`

**Interfaces:**
- Consumes: `DashboardRefreshCoordinator` (Task 5), `DashboardCard` (Task 6), `ServicesStore`
- Produces: `struct TemperatureCard: View` - 自定义温度传感器列表视图

- [x] **Step 1: 创建 TemperatureCard.swift**

```swift
import SwiftUI

struct TemperatureCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

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
        guard let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
        do {
            let systemResponse = try await client.getSystems()
            guard let system = systemResponse.items.first else { return }
            let recordsResponse = try await client.getSystemRecords(systemId: system.id, limit: 1)
            guard let latestRecord = recordsResponse.items.first?.stats else { return }
            let tempMap = latestRecord.temperatureSensors
            sensors = tempMap.map { (name: $0.key, celsius: $0.value) }
                .filter { $0.celsius > 0 }
                .sorted { $0.celsius > $1.celsius }
        } catch {}
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/TemperatureCard.swift
git commit -m "feat: add TemperatureCard with sensor list and linear gauges"
```

---

### Task 12: DockerOverviewCard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/DockerOverviewCard.swift`

**Interfaces:**
- Consumes: `DashboardRefreshCoordinator` (Task 5), `DashboardCard` (Task 6), `ArcaneAPIClient` (Task 3 via ServicesStore)
- Produces: `struct DockerOverviewCard: View` - 运行/总数徽章 + 横向容器状态滚动列表

- [x] **Step 1: 创建 DockerOverviewCard.swift**

```swift
import SwiftUI

struct DockerOverviewCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator

    @State private var containers: [ArcaneContainer] = []
    @State private var runningCount: Int = 0

    var body: some View {
        DashboardCard(title: "Docker", icon: "shippingbox") {
            VStack(spacing: 10) {
                HStack {
                    Label("\(runningCount)/\(containers.count)", systemImage: "circle.fill")
                        .foregroundStyle(AppTheme.running)
                        .font(.title3.bold())
                    Spacer()
                    if let instance = servicesStore.preferredInstance(for: .arcane) {
                        NavigationLink("管理") {
                            ArcaneDashboard(instanceId: instance.id)
                        }
                        .font(.subheadline)
                    }
                }

                if containers.isEmpty {
                    Text("无容器数据")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(containers) { container in
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(container.isRunning ? AppTheme.running : AppTheme.stopped)
                                        .frame(width: 10, height: 10)
                                    Text(container.name.replacingOccurrences(of: "^/", with: "", options: .regularExpression))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 80)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetchContainers()
        }
    }

    private func fetchContainers() async {
        guard let instance = servicesStore.preferredInstance(for: .arcane),
              let client = await servicesStore.arcaneClient(instanceId: instance.id) else { return }
        do {
            containers = try await client.getContainers()
            runningCount = containers.filter(\.isRunning).count
        } catch {}
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/DockerOverviewCard.swift
git commit -m "feat: add DockerOverviewCard with container status scroll list"
```

---

### Task 13: ServiceEntryCard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/ServiceEntryCard.swift`

**Interfaces:**
- Consumes: `DashboardCard` (Task 6), `ServicesStore`, `ServiceType.homeServices`
- Produces: `struct ServiceEntryCard: View` - 5 个核心服务 icon 导航入口

- [x] **Step 1: 创建 ServiceEntryCard.swift**

```swift
import SwiftUI

struct ServiceEntryCard: View {
    @Environment(ServicesStore.self) private var servicesStore

    var body: some View {
        DashboardCard(title: "服务", icon: "house.fill") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 12) {
                ForEach(ServiceType.homeServices, id: \.rawValue) { type in
                    if let instance = servicesStore.preferredInstance(for: type) {
                        NavigationLink(value: HomeServiceRoute(type: type, instanceId: instance.id)) {
                            VStack(spacing: 6) {
                                ServiceIconView(type: type, size: 28)
                                    .frame(width: 44, height: 44)
                                    .background(type.colors.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text(type.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
```

注意：`HomeServiceRoute` 定义为 `struct HomeServiceRoute: Hashable { let type: ServiceType; let instanceId: UUID }`，需要将其从 `HomeView.swift` 的 `private` 提升为 `internal`，或在新 HomeView 中重新声明。

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/ServiceEntryCard.swift
git commit -m "feat: add ServiceEntryCard with 5 core service shortcuts"
```

---

### Task 14: ArcaneDashboard

**Files:**
- Create: `HomelabSwift/Homelab/Views/Arcane/ArcaneDashboard.swift`

**Interfaces:**
- Consumes: `ArcaneAPIClient` (Task 3 via ServicesStore), `ArcaneContainer` (Task 1)
- Produces: `struct ArcaneDashboard: View` - 容器列表，支持启停操作

- [x] **Step 1: 创建 ArcaneDashboard.swift**

```swift
import SwiftUI

struct ArcaneDashboard: View {
    @Environment(ServicesStore.self) private var servicesStore

    let instanceId: UUID

    @State private var containers: [ArcaneContainer] = []
    @State private var isLoading = true
    @State private var actionInProgress: Set<String> = []

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if containers.isEmpty {
                Text("无容器")
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ForEach(containers) { container in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(container.isRunning ? AppTheme.running : AppTheme.stopped)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(container.name.replacingOccurrences(of: "^/", with: "", options: .regularExpression))
                                .font(.body.weight(.medium))
                            Text(container.image)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        if container.isRunning {
                            Button("停止") {
                                performAction(.stop, on: container.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(AppTheme.stopped)
                        } else {
                            Button("启动") {
                                performAction(.start, on: container.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(AppTheme.running)
                        }
                    }
                    .opacity(actionInProgress.contains(container.id) ? 0.5 : 1.0)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Arcane")
        .task { await fetchContainers() }
        .refreshable { await fetchContainers() }
    }

    private func fetchContainers() async {
        guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
        do {
            containers = try await client.getContainers()
        } catch {}
        isLoading = false
    }

    private func performAction(_ action: ContainerAction, on id: String) {
        Task {
            guard let client = await servicesStore.arcaneClient(instanceId: instanceId) else { return }
            actionInProgress.insert(id)
            do {
                try await client.containerAction(id: id, action: action)
                await fetchContainers()
            } catch {}
            actionInProgress.remove(id)
        }
    }
}
```

- [x] **Step 2: Commit**

```bash
git add HomelabSwift/Homelab/Views/Arcane/ArcaneDashboard.swift
git commit -m "feat: add ArcaneDashboard with container list and start/stop controls"
```

---

### Task 15: HomeView 重构

**Files:**
- Modify: `HomelabSwift/Homelab/Views/Home/HomeView.swift`

**Interfaces:**
- Consumes: All Dashboard cards (Tasks 6-13), `DashboardRefreshCoordinator` (Task 5), `ServicesStore` (existing)
- Produces: 新的 `HomeView` - ScrollView + LazyVGrid 2-col 卡片流

- [x] **Step 1: 创建新 HomeView 替换旧实现**

```swift
import SwiftUI

struct HomeView: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(Localizer.self) private var localizer

    @State private var coordinator = DashboardRefreshCoordinator()
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
```

- [x] **Step 2: 移除 HomeView.swift 中残留的旧代码**

删除以下不再需要的类型和代码：
- `OverviewStripModel` - 移除整个 struct
- `ServiceGridEntry` - 移除整个 enum
- `ServiceSummaryInfo` - 移除整个 struct
- `ServiceCardContent` - 移除整个 View
- `ServiceOrderSheet` - 保留不移除（仍在使用）
- 所有 `fetchOverviewStrip`、`fetchAllSummaryData`、`fetchSummary`、`fetchBeszelSystemMetrics`、`fetchContainerStripMetrics`、`fetchPortainerContainerMetrics` 等数据获取方法
- 所有 `overviewStatusStrip`、`serviceGrid`、`emptyOverviewSection`、`tailscaleSection`、`footerSection` 等旧 UI section
- `columns`、`hiddenServiceKeys`、`visibleTypes`、`hasServices`、`connectedHomeCount`、`gridEntries`、`hasUnreachableService`、`reachabilityHash`、`preferredSelectionHash`、`suppressTailscaleSection` 等旧的 computed properties
- `ServiceIconView` struct（移至 `ServiceIconView.swift` 文件以便复用，或保留在文件中）

保留：
- `ServiceOrderSheet` View（仍被使用）
- `HomeServiceRoute` struct（移到文件顶部 `internal` 级别）
- ServiceIconView（提取为独立 struct 复用，供 ServiceEntryCard 引用）

- [x] **Step 3: Commit**

```bash
git add HomelabSwift/Homelab/Views/Home/HomeView.swift
git commit -m "feat: refactor HomeView to Dashboard card grid layout with 10s polling"
```

---

### Task 16: iOS 编译验证

**Description:** 运行 Android/iOS 编译检查确保全部通过（仅 iOS 变更，但仍验证 Android 不受影响）。

- [x] **Step 1: iOS 编译检查**

```bash
cd HomelabSwift
xcodebuild build \
  -project Homelab.xcodeproj \
  -scheme Homelab \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/homelab-ios-dd \
  CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED

- [x] **Step 2: 检查是否需要 git commit 修复**

如有编译错误，修复后提交。

- [x] **Step 3: 所有提交完成后查看 git log 确认**

```bash
git log --oneline -20
```
