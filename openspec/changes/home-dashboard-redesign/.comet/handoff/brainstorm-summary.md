# Brainstorm Summary

- Change: home-dashboard-redesign
- Date: 2026-07-14

## 确认的技术方案

**布局**：紧凑型 2 列网格卡片 Dashboard，ScrollView 垂直滚动

**卡片组件**（模块化独立卡片 + DashboardRefreshCoordinator 10s 轮询）：

| 卡片 | 数据源 | 图表类型 | 内容 |
|------|--------|---------|------|
| SystemHealthCard | Beszel | 无 | OMV 在线状态、主机名、运行时间 |
| CPUMonitorCard | Beszel | 环形仪表 (Gauge) | 百分比 + 负载 |
| MemoryMonitorCard | Beszel | 堆叠条形 | 已用/缓存/空闲 + GB 数 |
| DiskMonitorCard | Beszel | 甜甜圈 (Donut) | 各卷已用/可用 |
| TemperatureCard | Beszel | 温度计进度条 | °C 数值 |
| DockerOverviewCard | Arcane | 无 | 运行/停止计数、横向容器状态列表 |
| ServiceEntryCard | 本地 | 无 | 5 个核心服务快捷入口 |

**技术架构**：方案 A — 模块化独立卡片，各自 `.task {}` 数据加载，DashboardRefreshCoordinator 统一刷新

**认证**：Arcane API Key + JWT 双模式

## 关键取舍与风险

- 紧凑型 2 列网格优先信息密度，牺牲部分视觉留白
- 不实现卡片拖拽排序（后续迭代）
- Portainer 代码保留不删除（向后兼容）
- Arcane API 可能存在版本兼容风险

## 测试策略

- 各卡片组件独立单元测试
- ArcaneAPIClient 接口测试（mock API）
- 编译检查验证 Swift Charts 集成

## Spec Patch

无
