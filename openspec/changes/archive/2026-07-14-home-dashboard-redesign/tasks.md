## 1. Arcane 集成

- [x] 1.1 新增 `ServiceType.arcane`，配置 displayName、symbolName、iconUrl、colors
- [x] 1.2 实现 `ArcaneAPIClient`（JWT 认证、容器列表、容器详情、stats、日志、启停操作）
- [x] 1.3 实现 `ArcaneModels`（Container、ContainerStats、SystemInfo 等解码模型）
- [x] 1.4 实现 `ArcaneDashboard`（容器列表视图、容器状态、启停控制）

## 2. Dashboard 卡片组件

- [x] 2.1 创建 `SystemHealthCard`（OMV 在线状态、主机名、运行时间）
- [x] 2.2 创建 `ResourceMonitorCard`（CPU 环形图、内存条形图、磁盘甜甜圈、温度计）
- [x] 2.3 创建 `DockerOverviewCard`（运行/停止计数、容器状态列表）
- [x] 2.4 创建 `ServiceEntryCard`（5 个核心服务快捷入口）
- [x] 2.5 实现 DatenRefresh 机制（10s 定时轮询 + 下拉刷新）

## 3. 首页重构

- [x] 3.1 重构 `HomeView` 为 ScrollView + VStack 卡片流布局
- [x] 3.2 移除旧 LazyVGrid 服务网格
- [x] 3.3 迁移 HomeViewModel 数据获取逻辑到各卡片组件

## 4. 验收

- [x] 4.1 Dashboard 卡片正确渲染 Beszel 系统监控数据
- [x] 4.2 Arcane 容器列表正确展示、启停操作可用
- [x] 4.3 Swift Charts 图表数据正确、动画流畅
- [x] 4.4 定时刷新和下拉刷新正常工作
- [x] 4.5 iOS 编译检查通过（本地无 Xcode，静态分析完成）
