---
comet_change: home-service-overview
role: technical-design
canonical_spec: openspec
archived-with: 2026-07-14-home-service-overview
status: final
---

# Home 服务总览（含 MVP 状态摘要条）技术设计

## 背景

第一标签目前语义偏「启动器」：Tab 文案为「首页 / Home」，大标题为品牌名 `HomeLab`，页脚与连接数徽章信息重复，缺少 Dashboard / 服务总览体感。用户期望在总览上看到 Docker / 系统占用一类信息；产品模型是 **先添加服务，再展示该服务摘要**，而非内置未配置的监控面板。

OpenSpec change：`home-service-overview`。Canonical 需求见  
`openspec/changes/home-service-overview/specs/home-dashboard-overview/spec.md`。

## 目标

1. 第一标签在文案与图标上明确为 **服务总览**（中：总览 / 服务总览；英：Overview / Service Overview）。
2. Tab 图标改为网格语义：`square.grid.2x2.fill`。
3. `HomeView` **轻量分层**：标题区清晰、去掉与连接数重复的 footer 噪音、无服务时有可读空态。
4. **MVP 顶部状态摘要条**（OverviewStatusStrip）：
   - 已配置且可达的 **Beszel** → CPU% / 内存%（或等价可用字段）
   - 已配置且可达的 **Portainer** → 运行中 / 总容器数；无 Portainer 时可降级到 Dockhand / Dockmon / Komodo 之一
   - 均无相关实例 → **不展示虚假指标**
5. 文档：取消 P5；平台表述统一 iOS。

## 非目标

- 完整 P4：`DashboardRepository`、OMV SMART 只读聚合、多源大卡墙
- 未配置服务时伪造 Docker / 系统占用
- qBittorrent 任务操作、Sonarr 默认隐藏、抬升 `IPHONEOS_DEPLOYMENT_TARGET`
- 重做书签 / 媒体 Tab / 独立 `DashboardView` 导航重构

## 架构与组件

```
ContentView (TabView)
  Tab Overview [square.grid.2x2.fill]
    └── HomeView (NavigationStack)
          ├── headerSection          // launcherTitle + count badge + reorder
          ├── overviewStatusStrip    // NEW: Beszel / container summary (optional)
          ├── tailscaleSection       // existing, conditional
          ├── serviceGrid            // existing dual-column cards
          └── footerSection          // de-dupe vs badge; empty guidance
```

### 改动面

| 区域 | 文件 | 变更 |
|------|------|------|
| Tab 图标/文案 | `ContentView.swift`，`Translations+Chinese/English` | `tabHome`、SF Symbol |
| 大标题 | `Translations` + `HomeView.headerSection` | `launcherTitle` 改为功能标题 |
| 摘要条 | `HomeView.swift`（private 视图/状态即可） | 拉取与展示 MVP 指标 |
| 文档 | `docs/myhomelab-roadmap.md`，`docs/decisions.md` | P5 取消、统一 iOS |

不强制抽取 `OverviewHeader` 独立类型（路径 A'：原位轻改）。

## 数据流：OverviewStatusStrip

1. 与现有 `summaryRefreshID` / `isViewVisible` 同生命周期刷新。
2. 系统段：`servicesStore` 中 preferred（或首个可达）Beszel 实例 → 现有 `beszelClient` → `getSystems()` / 系统 info 中的 `cpu`、内存相关字段（沿用 `BeszelSystemInfo` / records 已有模型，不新增 API 面）。
3. 容器段：preferred 可达 Portainer → 复用现有 Portainer endpoints + containers 计数逻辑（与卡片 summary 同源思路）；否则尝试 Dockhand / Dockmon / Komodo 的 summary API（与 `fetchSummary` 分支一致）。
4. 并发：在 `HomeView` 私有 async 方法内对 1–2 个源并行请求即可；**不**引入 Repository 层。
5. 错误：该段显示「—」或隐藏；**不得**用随机/缓存过期数据冒充实时值。
6. 与 per-card summary 可能重复请求：MVP 可接受；后续 change 再合并。

## 文案键

| 键 | zh-CN | en |
|----|-------|-----|
| `tabHome` | 总览 | Overview |
| `launcherTitle` | 服务总览 | Service Overview |

可选新增：

- 摘要条无数据源时的一行次要引导（例如「添加 Beszel 或 Portainer 以显示系统/容器摘要」）——若实现选择「完全隐藏条」则可不新增键。

设置里复用 `tabHome` 的分组标签会同步变为「总览」——与 Tab 一致，可接受。

## 布局细节

- Header：保留连接数徽章与排序；标题使用新 `launcherTitle`。
- Footer：删除与徽章重复的「N 已连接」式重复强调；无服务时可把引导放在网格区或 footer。
- 卡片 `ServiceCardContent`、网格列数、登录 sheet、排序 sheet：**行为不变**。

## 文档变更要点

- `myhomelab-roadmap.md`：P5（中文化/飞牛风）标为**已取消**；平台改为**统一 iOS**（不做独立 macOS 产品路线；Android 仍非产品路线）。
- `decisions.md`：与上述一致；一期「iOS + macOS」表述改为统一 iOS 架构决策。
- 可一句提到首页 MVP 摘要条；完整 OMV/P4 聚合仍属后续。

## 测试策略

1. **编译**：AGENTS.md iOS compile check（本 change 触达 Swift + 文档）。
2. **手动验收**（对照 delta spec）：
   - 冷启动落在第一标签；顺序 总览 → 媒体 → 书签 → 设置
   - 中英文 Tab/大标题/图标正确
   - 无 Beszel/Portainer：无虚假 CPU/容器数
   - 仅 Beszel / 仅 Portainer / 两者皆有：摘要段符合预期
   - 不可达实例：不崩溃，段隐藏或「—」
   - 已配置其他服务可进入；书签可进
3. **单元测试**：无强制；若抽出纯格式化函数可补小测。

## 风险

| 风险 | 缓解 |
|------|------|
| 用户未加 Beszel/Portainer 仍「看不到 Docker/系统」 | 空态/引导说明依赖已配置服务；完整监控另 change |
| 重复 API 负载 | MVP 接受；刷新与可见性门控 |
| 摘要条被当成完整 Dashboard | 文案用「总览」非「监控中心」；不做 OMV 大卡 |

## 实现任务映射（相对 tasks.md）

实现阶段应在既有 tasks 上补充摘要条相关勾选项（build 时更新 `tasks.md`），建议包含：

- 本地化与 Tab 图标
- HomeView header/footer/空态
- OverviewStatusStrip 数据与 UI
- 文档 P5 / 平台
- 编译与手动验收

## 开放实现选择（不阻塞）

- 无数据源时：完全隐藏 strip vs 一行引导文案（推荐引导一行，避免「坏了」的感觉）。
- 多 Beszel 系统：展示 preferred 系统或在线系统聚合均值——实现选「首选/第一在线系统」即可，并在代码注释标明。
