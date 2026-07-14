# Comet Design Handoff

- Change: home-dashboard-redesign
- Phase: design
- Mode: compact
- Context hash: 75f341a659bf0055814b555d13af8083a3421cf214b33f014d80153e5798176d

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/home-dashboard-redesign/proposal.md

- Source: openspec/changes/home-dashboard-redesign/proposal.md
- Lines: 1-31
- SHA256: 1eaaefe0e6cdc9bebab3140ac18d74e561731e9edcae6506788e011a060bd29e

```md
## Why

当前首页是简单的服务图标网格，缺乏系统级监控能力。用户需要一个现代化的 NAS Dashboard，能直观查看 OMV 服务器资源状态、Docker 容器运行情况、以及核心服务的快速概览。

## What Changes

- **Arcane 集成**：新增 `ServiceType.arcane`，替代 Portainer 作为 Docker 容器管理后端
- **首页重构为 Dashboard**：从服务图标网格改为垂直滚动卡片式布局
  - 系统健康概览（OMV 状态、运行时间）
  - 资源监控卡片（CPU/内存/磁盘/温度，使用 Swift Charts 饼图/环形图）
  - Docker 容器概览（运行/停止计数、容器状态列表）
  - 服务快速入口区（truenas、proxmox、qbittorrent 等 5 个核心服务）
- 采用 iOS 26+ 最新 SwiftUI 语法、Swift Charts、SF Symbols 6
- 参考主流 NAS App（TrueNAS、CasaOS、Unraid）的 Dashboard 设计模式

## Capabilities

### New Capabilities

- `dashboard-system-monitoring`: 系统资源监控 Dashboard，展示 CPU/内存/磁盘/温度的实时图表
- `arcane-docker-management`: Arcane Docker 容器管理集成，容器列表、启停、日志、状态
- `dashboard-widget-system`: 可定制卡片式 Dashboard Widget 系统

### Modified Capabilities

- `home-view`: 首页从服务网格改为 Dashboard 卡片流

## Impact

- **iOS**：`HomeView` 全面重构、新增 Arcane API 客户端和模型、新增 Swift Charts 图表组件
- **非目标**：不修改 Android 端、不删除现有服务集成代码、Immich/Emby/OpenList 卡片留到后续 change

```

## openspec/changes/home-dashboard-redesign/design.md

- Source: openspec/changes/home-dashboard-redesign/design.md
- Lines: 1-56
- SHA256: 96ddbc653fb319485a9cbfff14fb9fb483ddcc617b889ae3e9fa00276e051b70

```md
## Context

- 当前首页为 `HomeView.swift`，使用 `LazyVGrid` 展示服务图标网格
- `ServiceType.homeServices` 当前包含 5 个核心服务（truenas、openlist、proxmox、beszel、portainer）
- 已有 `BeszelAPIClient` 提供完整系统监控 API（CPU/内存/磁盘/温度/S.M.A.R.T.）
- 已有 `PortainerAPIClient` 提供 Docker 管理 API（将被 Arcane 替代）
- 现有 `SettingsStore` 管理 `serviceOrder` 和 `hiddenServices`

## Goals / Non-Goals

**Goals:**
- 首页改为垂直滚动卡片式 Dashboard 布局
- 资源监控卡片使用 Swift Charts（环形图/饼图展示 CPU、内存、磁盘、温度）
- 新增 Arcane API 集成（JWT 认证、容器 CRUD、日志、stats）
- Docker 容器概览卡片（运行/停止计数、每个容器状态指示器）
- 保留 5 个核心服务的快速入口

**Non-Goals:**
- 不删除 Portainer 相关代码（保持兼容）
- 不修改 Immich/Emby/OpenList（后续 change）
- 不修改 Android 端
- 不实现 Dashboard 卡片拖拽排序（后续迭代）

## Decisions

1. **布局方案：ScrollView + VStack 卡片流**
   - 参考 Apple Health App 的卡片式布局
   - 每个内容块为一个独立 Card 组件，圆角、系统背景色
   - 卡片间用 `padding` 和背景色区分

2. **图表选型：Swift Charts**
   - CPU：Gauge 环形仪表（带百分比标签）
   - 内存：堆叠条形图（已用/缓存/空闲）
   - 磁盘：甜甜圈图（已用/可用）
   - 温度：温度计式进度条

3. **Arcane 认证：API Key 优先**
   - 用户配置 `X-API-Key` 作为认证方式
   - 也支持 JWT（用户名+密码）作为备用

4. **数据刷新策略：定时轮询 + 下拉刷新**
   - 每 10 秒自动刷新监控数据
   - 支持手动下拉刷新
   - 进入后台时停止轮询

## Risks / Trade-offs

- [风险] Arcane API 可能在未来版本变更，需做好版本兼容
- [风险] 频繁轮询可能增加服务器负担，需合理设置刷新间隔
- [权衡] 卡片式布局内存占用高于简单图标网格，需注意性能

## Migration Plan

- 新用户默认进入 Dashboard 视图
- 保留现有服务详情页面的导航入口
- Portainer 代码保留不删除，用户如有配置可继续使用

```

## openspec/changes/home-dashboard-redesign/tasks.md

- Source: openspec/changes/home-dashboard-redesign/tasks.md
- Lines: 1-28
- SHA256: f504803204cf962810c8119646d44b0a08da015eb4ccd4da26e470a0b9a9cc80

```md
## 1. Arcane 集成

- [ ] 1.1 新增 `ServiceType.arcane`，配置 displayName、symbolName、iconUrl、colors
- [ ] 1.2 实现 `ArcaneAPIClient`（JWT 认证、容器列表、容器详情、stats、日志、启停操作）
- [ ] 1.3 实现 `ArcaneModels`（Container、ContainerStats、SystemInfo 等解码模型）
- [ ] 1.4 实现 `ArcaneDashboard`（容器列表视图、容器状态、启停控制）

## 2. Dashboard 卡片组件

- [ ] 2.1 创建 `SystemHealthCard`（OMV 在线状态、主机名、运行时间）
- [ ] 2.2 创建 `ResourceMonitorCard`（CPU 环形图、内存条形图、磁盘甜甜圈、温度计）
- [ ] 2.3 创建 `DockerOverviewCard`（运行/停止计数、容器状态列表）
- [ ] 2.4 创建 `ServiceEntryCard`（5 个核心服务快捷入口）
- [ ] 2.5 实现 DatenRefresh 机制（10s 定时轮询 + 下拉刷新）

## 3. 首页重构

- [ ] 3.1 重构 `HomeView` 为 ScrollView + VStack 卡片流布局
- [ ] 3.2 移除旧 LazyVGrid 服务网格
- [ ] 3.3 迁移 HomeViewModel 数据获取逻辑到各卡片组件

## 4. 验收

- [ ] 4.1 Dashboard 卡片正确渲染 Beszel 系统监控数据
- [ ] 4.2 Arcane 容器列表正确展示、启停操作可用
- [ ] 4.3 Swift Charts 图表数据正确、动画流畅
- [ ] 4.4 定时刷新和下拉刷新正常工作
- [ ] 4.5 iOS 编译检查通过

```
