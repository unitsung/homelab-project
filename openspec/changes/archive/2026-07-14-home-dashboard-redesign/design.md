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
