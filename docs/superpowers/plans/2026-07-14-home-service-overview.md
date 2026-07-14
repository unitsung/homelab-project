---
change: home-service-overview
design-doc: docs/superpowers/specs/2026-07-14-home-service-overview-design.md
base-ref: fd7bcdfd34b5f2360f6e6341a2859fe254f5c093
---

# Home 服务总览 + MVP 状态摘要条 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将第一标签改为「服务总览」语义与轻量布局，并在已配置 Beszel/Portainer（或 Dock* 降级）时展示只读 MVP 状态摘要条；同步文档取消 P5 与统一 iOS 表述。

**Architecture:** 原位修改 `ContentView` + `HomeView` + Localization，不拆 `DashboardView`、不引入 `DashboardRepository`。摘要条与现有 `summaryRefreshID` / 可见性生命周期对齐，私有 async 拉取 1–2 个数据源。

**Tech Stack:** SwiftUI、现有 `ServicesStore` / Beszel / Portainer API clients、项目 Localization 结构。

## Global Constraints

- 产物语言：`zh-CN`（注释与用户可见中文键以现有 Localizer 为准）
- 不抬升 `IPHONEOS_DEPLOYMENT_TARGET`
- 不引入废弃 API
- 未配置监控/容器源时**禁止伪造** CPU/内存/容器数
- 不做 OMV SMART / 完整 P4 聚合
- Tab 顺序固定：总览 → 媒体 → 书签 → 设置
- Canonical spec：`openspec/changes/home-service-overview/specs/home-dashboard-overview/spec.md`
- Design Doc：`docs/superpowers/specs/2026-07-14-home-service-overview-design.md`

---

## 文件映射

| 文件 | 职责 |
|------|------|
| `HomelabSwift/Homelab/Localization/Translations.swift` | 若需新键（摘要引导）则声明 |
| `HomelabSwift/Homelab/Localization/Translations+Chinese.swift` | `tabHome`、`launcherTitle`、可选引导文案 |
| `HomelabSwift/Homelab/Localization/Translations+English.swift` | 同上英文 |
| `HomelabSwift/Homelab/Views/ContentView.swift` | Tab SF Symbol |
| `HomelabSwift/Homelab/Views/Home/HomeView.swift` | header/footer/空态/OverviewStatusStrip |
| `docs/myhomelab-roadmap.md` | P5 取消、统一 iOS |
| `docs/decisions.md` | 与路线图一致 |
| `openspec/changes/home-service-overview/tasks.md` | 勾选进度 |

---

### Task 1: 文档对齐（P5 取消 + 统一 iOS）

**Files:**
- Modify: `docs/myhomelab-roadmap.md`
- Modify: `docs/decisions.md`
- Modify: `openspec/changes/home-service-overview/tasks.md`（勾选 1.1–1.2）

**Interfaces:**
- Consumes: Design Doc 文档要点
- Produces: 读者可见的路线图/决策一致表述

- [x] **Step 1: 更新路线图**

在 `docs/myhomelab-roadmap.md`：
1. 顶部平台表述改为：**统一 iOS 架构**（非独立 macOS 产品路线；Android 不做）。删除或改写「iPhone + Mac 双端 / iOS + macOS 统一」中暗示独立 macOS 产品线的句子。
2. 阶段列表中 **P5 中文化/飞牛风** 标明 **已取消**，不得仍列为待执行。
3. `## Phase 5` 章节标题或正文注明已取消及原因（产品决策），避免执行清单仍像待办。

- [x] **Step 2: 更新 decisions.md**

在 `docs/decisions.md`：
1. 「一期」平台行改为统一 iOS 架构决策（可保留历史备注，但结论必须明确）。
2. P5 相关条目与路线图一致：已取消。

- [x] **Step 3: 勾选 tasks 1.1–1.2 并提交**

```bash
# 编辑 tasks.md 将 1.1 1.2 标为 [x]
git add docs/myhomelab-roadmap.md docs/decisions.md openspec/changes/home-service-overview/tasks.md
git commit -m "$(cat <<'EOF'
docs: cancel P5 and unify platform as iOS-only

Align roadmap and decisions with home-service-overview scope.
EOF
)"
```

---

### Task 2: 本地化与 Tab 图标

**Files:**
- Modify: `HomelabSwift/Homelab/Localization/Translations+Chinese.swift`（`tabHome`、`launcherTitle`）
- Modify: `HomelabSwift/Homelab/Localization/Translations+English.swift`
- Modify: `HomelabSwift/Homelab/Views/ContentView.swift`（约第 16 行 `systemImage`）
- Modify: `openspec/changes/home-service-overview/tasks.md`（2.1–2.2）

**Interfaces:**
- Consumes: 现有 `localizer.t.tabHome` / `launcherTitle`
- Produces: 中文「总览」/「服务总览」；英文 Overview / Service Overview；图标 `square.grid.2x2.fill`

- [x] **Step 1: 改中英文文案**

`Translations+Chinese.swift`：
```swift
tabHome: "总览",
// ...
launcherTitle: "服务总览",
```

`Translations+English.swift`：
```swift
tabHome: "Overview",
// ...
launcherTitle: "Service Overview",
```

- [x] **Step 2: 改 Tab 图标**

`ContentView.swift`：
```swift
Tab(localizer.t.tabHome, systemImage: "square.grid.2x2.fill") {
    HomeView()
}
```

- [x] **Step 3: 确认 Tab 顺序未改**

四个 `Tab(...)` 顺序仍为：Home → Media → Bookmarks → Settings。

- [x] **Step 4: 勾选 2.1–2.2 并提交**

```bash
git add HomelabSwift/Homelab/Localization/Translations+Chinese.swift \
  HomelabSwift/Homelab/Localization/Translations+English.swift \
  HomelabSwift/Homelab/Views/ContentView.swift \
  openspec/changes/home-service-overview/tasks.md
git commit -m "$(cat <<'EOF'
feat: rename home tab to Overview and use grid symbol

Chinese 总览 / 服务总览; English Overview / Service Overview.
EOF
)"
```

---

### Task 3: HomeView 标题区 / footer / 空态轻量分层

**Files:**
- Modify: `HomelabSwift/Homelab/Views/Home/HomeView.swift`（`headerSection`、`footerSection`、`body` 内 `serviceGrid` 前后）
- Optional Modify: Localization 若新增空态键
- Modify: `openspec/changes/home-service-overview/tasks.md`（3.1–3.3）

**Interfaces:**
- Consumes: `launcherTitle`、`connectedHomeCount`、`hasServices`
- Produces: 清晰标题区；footer 不重复连接数；无服务可读空态

- [x] **Step 1: Header**

保持大标题 `localizer.t.launcherTitle`、连接数徽章、排序按钮；微调 `.padding(.bottom, …)` 使标题区与下方内容分层更清晰（例如 bottom 20）。**不要**改徽章计算逻辑。

- [x] **Step 2: Footer 去重**

删除或改写当前：
```swift
Text("\(localizer.t.launcherServices) • \(connectedHomeCount) \(localizer.t.launcherConnected.sentenceCased())")
```
改为不重复展示 `connectedHomeCount` 的轻量文案，例如仅在有服务时显示简短 `launcherServices` 类说明，或缩小为次要 spacing spacer。推荐：有服务时 footer 仅保留底部安全间距（无数字文案）；无服务时由空态承担说明。

- [x] **Step 3: 空态**

当 `!hasServices` 时，在 `serviceGrid` 位置或之前展示 `VStack`：
- 主文案：说明尚无首页服务 / 可去添加（复用现有键如 `launcherTapToConnect` 或新增 `overviewEmptyTitle` / `overviewEmptyMessage`）
- 不崩溃、不伪造指标

若新增键，同步 `Translations.swift` + 中英文文件。

- [x] **Step 4: 勾选 3.x 并提交**

```bash
git add HomelabSwift/Homelab/Views/Home/HomeView.swift \
  HomelabSwift/Homelab/Localization/ \
  openspec/changes/home-service-overview/tasks.md
git commit -m "$(cat <<'EOF'
feat: clarify home overview header, empty state, and footer

Remove duplicate connection count from footer; improve empty guidance.
EOF
)"
```

---

### Task 4: OverviewStatusStrip（Beszel + 容器源）

**Files:**
- Modify: `HomelabSwift/Homelab/Views/Home/HomeView.swift`
- Optional: Localization 引导文案键
- Modify: `openspec/changes/home-service-overview/tasks.md`（4.1–4.4）

**Interfaces:**
- Consumes:
  - `servicesStore.preferredInstance(for: .beszel)` / `beszelClient`
  - `getSystems()` / system info `cpu`、内存字段（`BeszelSystemInfo` / records）
  - Portainer：`portainerClient` + endpoints/containers 计数（对齐现有 `fetchSummary` 中 portainer 分支）
  - 降级：`.dockhand` / `.dockmon` / `.komodo` 的 summary API（与现有 `fetchSummary` 一致）
- Produces: 可选只读摘要条 UI + 状态模型

- [x] **Step 1: 定义轻量状态**

在 `HomeView` 内：
```swift
private struct OverviewStripModel: Equatable {
    var systemCPU: String?      // e.g. "23%"
    var systemMemory: String?   // e.g. "61%"
    var containersRunning: Int?
    var containersTotal: Int?
    var isLoading: Bool
    var showGuidance: Bool      // 无数据源时 true
}
@State private var overviewStrip = OverviewStripModel(
    systemCPU: nil, systemMemory: nil,
    containersRunning: nil, containersTotal: nil,
    isLoading: false, showGuidance: false
)
```

- [x] **Step 2: 实现 `fetchOverviewStrip()`**

规则：
1. `isViewVisible == false` 则 return
2. 解析 preferred 可达 Beszel；若有，取第一台在线系统或 preferred 系统的 CPU/内存，格式化为整数百分比字符串；失败则该段 nil
3. 解析 preferred 可达 Portainer；若有，汇总 running/total containers；否则依次试 dockhand/dockmon/komodo
4. 若系统段与容器段皆 nil 且无对应已配置实例 → `showGuidance = true`（或完全不显示条，二选一：**实现选引导一行**）
5. 错误吞掉为 nil，不抛到 UI 崩溃

在现有 `.task(id: summaryRefreshID)` 中 `await fetchOverviewStrip()`（可与 `fetchAllSummaryData` 顺序或并行；MVP 顺序可接受）。

- [x] **Step 3: UI `overviewStatusStrip`**

放在 `headerSection` 与 `tailscaleSection` 之间：
- `isLoading`：小 `SkeletonLoader` 或 `ProgressView`
- 有 CPU/内存：横向展示
- 有容器：展示 `running / total`
- `showGuidance`：次要 caption 引导添加 Beszel/Portainer
- 使用现有 `glassCard` / `AppTheme` 风格，高度紧凑（非大监控卡）

- [x] **Step 4: 手动逻辑自检清单（写在 commit body 或 tasks 注释）**

- 无 Beszel/Portainer：无虚假数字
- 仅 Beszel / 仅 Portainer / 两者
- 不可达：不崩溃

- [x] **Step 5: 勾选 4.x 并提交**

```bash
git add HomelabSwift/Homelab/Views/Home/HomeView.swift \
  HomelabSwift/Homelab/Localization/ \
  openspec/changes/home-service-overview/tasks.md
git commit -m "$(cat <<'EOF'
feat: add home overview status strip for Beszel and containers

MVP read-only strip; no fake metrics without configured services.
EOF
)"
```

---

### Task 5: iOS 编译与 tasks 验收勾选

**Files:**
- Modify: `openspec/changes/home-service-overview/tasks.md`（5.1–5.2）

**Interfaces:**
- Consumes: 全部实现
- Produces: 编译通过证据 + 手动验收说明

- [x] **Step 1: 编译**

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

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 2: 记录手动验收**

在 tasks.md 5.2 旁或验证草稿中勾选说明：冷启动、Tab 顺序/文案/图标、空态、摘要条三场景、书签可进。

- [x] **Step 3: 勾选 5.x 并提交**

```bash
git add openspec/changes/home-service-overview/tasks.md
git commit -m "$(cat <<'EOF'
chore: mark home-service-overview tasks verified after iOS build

EOF
)"
```

---

## Spec 覆盖自检

| Spec 要求 | Task |
|-----------|------|
| 默认第一标签总览语义 + 文案 | 2, 3 |
| Tab 顺序 | 2（确认） |
| 布局可读、空态、footer 不重复连接数 | 3 |
| 可选状态摘要条 / 不伪造 | 4 |
| 文档 P5 + 统一 iOS | 1 |
| 编译与验收 | 5 |

---

## 元数据

```yaml
---
change: home-service-overview
design-doc: docs/superpowers/specs/2026-07-14-home-service-overview-design.md
base-ref: fd7bcdfd34b5f2360f6e6341a2859fe254f5c093
---
```
