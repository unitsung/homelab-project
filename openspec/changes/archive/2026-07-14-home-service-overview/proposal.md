## Why

当前第一标签名为「首页」，实际是服务启动器网格，信息层级偏平、缺少「Dashboard / 总览」体感；产品路线图中的 P5（中文化/飞牛风专项）已决定取消，平台表述也需与「统一 iOS 架构」对齐。先做服务总览布局优化（阶段 B），聚合监控 Dashboard（阶段 A）另开 change。

## What Changes

- 将第一标签定位为 **Dashboard / 服务总览**（文案与布局），**不改变**标签顺序：Dashboard → 媒体 → 书签 → 设置。
- 优化首页服务总览布局（信息层级、卡片密度、可读性）；书签功能保留。
- 更新 `docs/myhomelab-roadmap.md` / `docs/decisions.md`（如需）：**取消 P5**；平台明确为 **统一 iOS**（不做独立 macOS 路线；Android 仍不在产品路线）。
- 新代码避免废弃 API；**不**抬升 `IPHONEOS_DEPLOYMENT_TARGET`（维持现有部署目标）。

## Capabilities

### New Capabilities

- `home-dashboard-overview`: 第一标签 Dashboard 服务总览的信息架构、布局与默认入口体验。

### Modified Capabilities

- （无）

## Impact

- **iOS**：`ContentView`（标签文案/语义）、`Views/Home/HomeView.swift` 及相关组件/本地化键。
- **文档**：路线图 P5 与平台表述。
- **非目标**：聚合监控卡片（Beszel/OMV 等阶段 A）、qBittorrent 任务操作、Sonarr 默认隐藏、部署目标升到 iOS 27。
