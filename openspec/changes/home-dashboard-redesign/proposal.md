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
