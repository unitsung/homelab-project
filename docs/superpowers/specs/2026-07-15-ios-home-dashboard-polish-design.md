---
role: technical-design
platform: ios-only
status: approved
date: 2026-07-15
supersedes_in_part: 2026-07-14-home-dashboard-redesign-design.md
related_spec: openspec/specs/home-dashboard-overview/spec.md
---

# iOS 首页 Dashboard 打磨设计

## 1. 概述

将 iOS 首页从「服务总览」叙事打磨为 **PVE 式分段监控 Dashboard**：Beszel 为主数据源、监控卡片可拖拽排序、去掉综合温度卡、展示硬盘温度、保留服务快捷入口（含 Beszel / PVE / Arcane）；并修复 Arcane 登录缺用户名字段与各服务 URL placeholder。

**产品决策（已确认）**

| 决策 | 选择 |
|------|------|
| 「去掉服务总览」 | **A**：改文案/定位，**保留**服务入口 |
| 布局参考 | **Proxmox Dashboard** 分段结构 |
| 平台 | **仅 iOS**（Android 不跟） |
| 系统指标数据源 | **Beszel 为主** |
| 存储 | 用户环境为 OMV；**本版不集成 OMV/TrueNAS** |
| PVE | **不展示任何首页指标**，仅服务入口 |
| ZFS / 完整 SMART | **本版不做**；Beszel 无可靠字段则隐藏 |
| 拖拽范围 | **仅监控卡片顺序**（不含服务入口、系统健康条） |
| 大标题 | **Homelab** |

## 2. 目标与非目标

### 目标

1. 去掉「服务总览 / Service Overview」产品语义；Tab 与标题改为首页/Dashboard 向。
2. 首页纵向结构对齐 PVE：顶栏 → 系统健康 → 可排序 2 列统计卡 → Docker → 服务入口。
3. 删除综合「温度」卡；新增「硬盘温度」卡（Beszel 传感器过滤）。
4. 监控卡片支持长按拖拽排序，顺序本地持久化。
5. Arcane 登录表单展示用户名；用户名+密码路径可提交。
6. 首页可添加 Beszel（服务添加列表已含则验证可用性）。
7. 各服务登录 URL placeholder 使用带默认端口的示例地址（仅 placeholder，不预填提交值）。

### 非目标

- Android 任何改动
- OMV / TrueNAS 客户端集成
- 首页 PVE 集群/节点/VM 指标块
- ZFS 专卡、完整 SMART 报告页
- 服务入口横滑的拖拽排序（本版仍可用现有排序 sheet）
- 引入新的第三方图表库（沿用 Swift Charts / 现有卡片）

## 3. 信息架构

```
HomeView (NavigationStack + ScrollView)
├── 顶栏
│   ├── 大标题: Homelab（localizer.t.launcherTitle）
│   └── 可选: 现有服务排序入口保留（服务隐藏/上下移，非卡片拖拽）
├── SystemHealthCard          // 全宽；不参与卡片拖拽
├── Reorderable metric grid   // 2 列；参与拖拽
│   ├── cpu
│   ├── memory
│   ├── disk
│   ├── diskTemperature       // 替换 TemperatureCard
│   └── docker                // 可占 2 列宽，仍参与顺序
└── ServiceEntryCard          // 全宽；服务入口 + 添加（含 Beszel、PVE、Arcane）
```

### 文案

| Key | 中文（现 → 新） | 英文（现 → 新） |
|-----|----------------|-----------------|
| `launcherTitle` | 服务总览 → **Homelab** | Service Overview → **Homelab** |
| `tabHome` | 总览 → **首页** | Overview → **Home** |

`openspec/specs/home-dashboard-overview` 中「服务总览 / Service Overview」强制要求需在实现 change 中改为 Dashboard/Homelab 语义。

## 4. 监控卡片

### 4.1 卡片清单与数据源

| id | 标题 | 数据源 | 无数据时 |
|----|------|--------|----------|
| `cpu` | CPU | `DashboardSystemStore` / Beszel system info | 隐藏或显示空态（推荐：**隐藏**于网格外，不伪造 %） |
| `memory` | 内存 | 同上 | 同上 |
| `disk` | 磁盘 | 同上 disk % / used | 同上 |
| `diskTemperature` | 硬盘温度 | Beszel records 的 temperature sensors，过滤 disk 类名 | 无匹配传感器 → **不显示卡片** |
| `docker` | Docker | 现有 `DockerOverviewCard`：优先 **Arcane** containers | 无 Arcane → 空态「无容器数据」或隐藏（保持现有行为，可轻量改为无实例时隐藏） |

**删除**：`TemperatureCard` 从 `HomeView` 移除（文件可保留一版后删，或改为 `DiskTemperatureCard` 重写）。

**明确不出现**：PVE 指标、ZFS 卡、综合 CPU/主板温度列表（除非传感器名命中 disk 过滤规则）。

### 4.2 硬盘温度传感器过滤

从 `Beszel` 最新 system records 的 `temperatureSensors`（`[String: Double]`）筛选名称（case-insensitive）匹配任一子串：

- `disk`, `hdd`, `ssd`, `nvme`, `drive`, `wd`, `seagate`, `smart`

排除明显 CPU/GPU/系统类（可选负向列表）：`cpu`, `core`, `gpu`, `package`, `pch`, `acpi`。

展示：名称 + °C + 简单色阶（&gt;60 warning，&gt;80 critical），样式可参考现有 `TemperatureCard` 但标题为「硬盘温度」。

### 4.3 拖拽排序与持久化

**模型**（建议放 `SettingsStore`）：

```swift
enum DashboardCardID: String, CaseIterable, Codable, Identifiable {
    case cpu, memory, disk, diskTemperature, docker
    var id: String { rawValue }
}

// SettingsStore
var dashboardCardOrder: [DashboardCardID]
// UserDefaults key: "homelab_dashboard_card_order"
// 默认: [.cpu, .memory, .disk, .diskTemperature, .docker]
// 加载时 normalize：补全新 id、去掉未知 id、去重
func setDashboardCardOrder(_ order: [DashboardCardID])
func moveDashboardCard(from: IndexSet, to: Int)
```

**交互**

- 仅在 metric 网格内长按拖拽（SwiftUI `draggable` / `dropDestination` 或 `onMove` 列表式，择一与 iOS 版本兼容的实现）。
- 不拖动 `SystemHealthCard`、`ServiceEntryCard`。
- 持久化在松手后立即写入 UserDefaults。

**可见性**：某卡因无数据源被隐藏时，**仍保留在 order 数组中**，仅 UI 不渲染，避免恢复数据后顺序丢失。

## 5. 服务入口与 PVE

- `ServiceEntryCard` 继续使用 `ServiceType.homeServices`：`truenas, openlist, proxmox, beszel, portainer, arcane`。
- **Beszel** 必须在「添加服务」未配置列表中可选；配置后出现在横滑入口。
- **Proxmox**：仅作为入口；首页**禁止**新增任何集群/节点/CPU/内存/VM 统计块。
- 服务入口排序仍走现有 `ServiceOrderSheet`（上下箭头），本版不改为拖拽。

## 6. 登录修复与 Placeholder

### 6.1 Arcane 用户名

现状：`ServiceLoginView` 的 `needsUsername` **未包含** `.arcane`，但提交路径 `case .arcane` 在无 API Key 时要求 `username` + `password` → 用户无法输入用户名。

改动：

1. `needsUsername` 加入 `.arcane`。
2. 若同时支持 API Key：UI 保持「API Key **或** 用户名+密码」二选一（与现有 `case .arcane` 分支一致）；展示用户名字段 + 密码字段，API Key 字段可保留。
3. `canSubmit`：Arcane 需满足 `apiKey 非空` **或** `(username 且 password)`（编辑模式允许沿用已存密钥）。

### 6.2 URL Placeholder

将通用 `loginUrlPlaceholder` 改为 **按 `ServiceType` 的默认示例**（placeholder only）：

| Service | 示例 placeholder |
|---------|------------------|
| beszel | `http://beszel.local:8090` |
| arcane | `http://arcane.local:3552` |
| portainer | `https://portainer.local:9443` |
| proxmox | `https://pve.local:8006` |
| truenas | `https://truenas.local` |
| openlist | `http://openlist.local:5244` |
| pihole | `http://pi.hole` 或 `http://pihole.local` |
| adguardHome | `http://adguard.local` |
| nginxProxyManager | `http://npm.local:81` |
| 其他 | 保留通用 `https://host:port` 或按常见默认端口补齐 |

实现建议：`ServiceType.urlPlaceholder: String` 或 `Localizer` 方法 `urlPlaceholder(for: ServiceType)`，`ServiceLoginView` 地址框使用该值。

## 7. 组件与数据流

```
DashboardRefreshCoordinator.refreshTrigger
        │
        ▼
┌───────────────────┐     preferredInstance(.beszel)
│ DashboardSystemStore │◄── BeszelAPIClient.getSystems / getSystemRecords
└───────────────────┘
        │
        ├── SystemHealthCard
        ├── CPU / Memory / Disk cards
        └── DiskTemperatureCard (records sensors)

DockerOverviewCard ──► preferredInstance(.arcane) ──► ArcaneAPIClient.getContainers

SettingsStore.dashboardCardOrder ──► HomeView grid order
```

- 无 Beszel 实例：依赖 Beszel 的健康条与 metric 卡不显示伪造数据；可在健康条位置显示简短「添加 Beszel」引导（可选，不阻塞）。
- 单卡请求失败：该卡显示错误或空态，不影响其他卡。
- 刷新：沿用现有 10s coordinator + 手动路径（若有）。

## 8. 文件影响（预期）

| 路径 | 变更 |
|------|------|
| `HomelabSwift/Homelab/Views/Home/HomeView.swift` | 布局、reorder 网格、去掉 TemperatureCard |
| `HomelabSwift/Homelab/Views/Dashboard/TemperatureCard.swift` | 删除或改写为 `DiskTemperatureCard.swift` |
| `HomelabSwift/Homelab/Views/Dashboard/*MonitorCard.swift` | 样式微调以贴近 PVE quick stats（可选） |
| `HomelabSwift/Homelab/Stores/SettingsStore.swift` | `dashboardCardOrder` 持久化 |
| `HomelabSwift/Homelab/Views/ServiceLogin/ServiceLoginView.swift` | Arcane username + per-type URL placeholder |
| `HomelabSwift/Homelab/Models/ServiceType.swift` | `urlPlaceholder`（若放模型侧） |
| `HomelabSwift/Homelab/Localization/Translations*.swift` | `launcherTitle`, `tabHome`, 新卡标题/引导文案 |
| `openspec/specs/home-dashboard-overview/spec.md` | 随 change 更新需求语义 |
| `HomelabSwift/HomelabTests/...` | 顺序 normalize、sensor 过滤、Arcane needsUsername 逻辑测试（能抽 pure func 则测） |

## 9. 错误处理

| 场景 | 行为 |
|------|------|
| 未配置 Beszel | 不显示 CPU/内存/磁盘/盘温数值；不伪造 |
| Beszel 不可达 | 健康条离线/错误；卡可显示上次缓存或空（现有 store 无缓存则空） |
| 无 disk 类传感器 | 不渲染盘温卡 |
| 未配置 Arcane | Docker 卡空态或隐藏 |
| Arcane 仅有 API Key | 仍可登录（无需用户名） |
| Arcane 仅用户名密码 | 表单可见用户名+密码且可提交 |

## 10. 测试与验收

### 自动化

- `DashboardCardID` order normalize 单元测试
- Disk temperature sensor name filter 单元测试
- Arcane 表单：`needsUsername` 含 arcane 的逻辑若抽到纯函数则测

### 手动 / 编译

- iOS compile check（`AGENTS.md` 中 `xcodebuild` 无签名 generic iOS）
- 真机/模拟器：拖拽顺序杀进程后仍保留；添加 Arcane 用户名密码成功；Beszel 添加后指标出现；无 PVE 指标块

### 验收清单

- [ ] 标题为 Homelab，Tab 为首页/Home
- [ ] 无「服务总览」主文案
- [ ] 无综合温度卡；有硬盘温度（有数据时）
- [ ] CPU/内存/磁盘/Docker 可见（有对应数据源时）
- [ ] 监控卡片可拖拽且持久化
- [ ] 服务入口仍在；含 Beszel；PVE 仅入口
- [ ] Arcane 可填用户名并添加成功
- [ ] URL placeholder 为各服务默认示例地址

## 11. 实现策略

原位增强现有 `HomeView` + `Views/Dashboard/*` + `DashboardSystemStore`（方案 A），不新建平行 Dashboard 根视图，不引入 OMV。

建议任务切分：

1. 文案 + Spec 语义调整  
2. `dashboardCardOrder` 持久化 + 纯函数测试  
3. `DiskTemperatureCard` + 移除综合温度  
4. `HomeView` reorder 网格 + PVE 式分段微调  
5. Arcane username + URL placeholders  
6. 编译验证与手工验收  

## 12. 风险与开放项

| 风险 | 缓解 |
|------|------|
| Beszel 传感器命名各异导致盘温为空 | 过滤规则可配置常量；无数据隐藏卡 |
| 拖拽手势与 ScrollView 冲突 | 使用系统推荐的 grid drag API；必要时 edit 模式开关 |
| Arcane API Key 与密码 UI 同时展示可能困惑 | 简短 hint：二选一 |
| `homeServices` 仅 6 项 | 本版不扩展列表；Beszel 已在列表中 |

**开放项（本版默认）**

- Docker 卡是否必须全宽：默认按 order 占 1 格；若内容过挤可在实现时改为 `GridItem` span 2。
- 重置卡片顺序：可选，实现时可用 Settings 一键恢复默认，非必须。

## 13. 自检记录

- [x] 无 TBD 占位需求  
- [x] 与用户确认决策一致（A 文案、Beszel、无 OMV、PVE 仅入口、拖拽仅卡片、Homelab 标题、iOS only）  
- [x] 与既有 2026-07-14 Dashboard 实现兼容（增强而非推倒）  
- [x] 范围可收敛为单一实现计划  
- [x] Arcane / placeholder 缺陷有明确文件锚点  
