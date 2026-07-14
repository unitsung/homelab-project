# Brainstorm Summary

- Change: home-service-overview
- Date: 2026-07-14
- Status: **已确认**

## 确认的技术方案

### 产品模型
- 总览不内置未配置的 Docker/系统面板；指标来自已添加服务
- Docker/系统：Beszel（CPU/内存）、Portainer 或 Dock* 降级（运行容器）
- 无相关实例：无假数据

### 路径 A'
- 原位轻改 HomeView + OverviewStatusStrip MVP
- 无 DashboardRepository / OMV SMART / P4 全量

### 文案与图标
- 中：tab「总览」、大标题「服务总览」
- 英：Overview / Service Overview
- SF Symbol：`square.grid.2x2.fill`

### UI
1. Header：标题 + 连接数 + 排序
2. OverviewStatusStrip（Beszel / Portainer 等，只读）
3. Tailscale（不变）
4. 服务网格（卡片逻辑基本不动）
5. Footer 去与连接数重复

### 文档
- 取消 P5；平台统一 iOS

## 关键取舍与风险
- 未添加 Beszel/Portainer 则看不到系统/容器摘要
- 与 per-card summary 可能重复请求（MVP 可接受）
- 相对纯布局范围扩大但仍单 change

## 测试策略
- iOS compile + 手动：无服务/仅 Beszel/仅 Portainer/两者/不可达
- 可选格式化单测

## Spec Patch
- 新增可选状态摘要条 requirement + 场景
- 保留默认 Tab、顺序、布局、文档要求
