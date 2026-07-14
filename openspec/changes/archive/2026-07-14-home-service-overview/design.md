## Context

- 第一标签 `ContentView` → `HomeView`：双列服务网格 + 摘要 + Tailscale 条，语义是启动器而非「Dashboard」。
- 标签顺序已符合产品选择：首页 → 媒体 → 书签 → 设置；书签与媒体不动。
- 文档中 P5（中文化/飞牛风）与「iPhone + Mac 双端」表述需与现决策对齐：统一 iOS 架构，P5 取消；聚合监控 Dashboard（A）后续独立 change。
- 部署目标保持现状；实现使用当前 SwiftUI 惯用 API，避免废弃 API。

## Goals / Non-Goals

**Goals:**

- 第一标签在文案与视觉上明确为 **Dashboard / 服务总览**。
- 优化总览布局的信息层级与可读性（标题区、连接计数、卡片、空态）。
- 同步路线图/决策文档：砍 P5、平台表述统一 iOS。

**Non-Goals:**

- 不做聚合监控首页（Beszel/OMV/Healthchecks 大卡片等阶段 A）。
- 不改动 qBittorrent 任务能力、Sonarr 默认可见性（另 change）。
- 不抬升 `IPHONEOS_DEPLOYMENT_TARGET`。
- 不重做书签。

## Decisions

1. **仅改语义与布局，不改 Tab 结构**  
   - 保持 4 Tab 与顺序；通过 `tabHome` / 大标题等本地化与 `HomeView` 结构表达 Dashboard。  
   - 备选：拆出独立 `DashboardView` 再嵌服务网格 → 本期不必要，改动面大。

2. **布局优化落在 HomeView 分层**  
   - 明确「总览标题 + 状态摘要 + 服务网格」区块；减少视觉噪音（如重复强调）。  
   - 不引入新导航框架。

3. **文档与代码同 change**  
   - `docs/myhomelab-roadmap.md`、`docs/decisions.md` 中 P5 / 平台行同步修改，避免路线图误导后续 Comet 选型。

4. **API 卫生**  
   - 触及 UI 时优先系统 `Tab`/`NavigationStack`/`glass` 等现行 API；不引入已标记废弃 API。

## Risks / Trade-offs

- [风险] 仅改文案用户仍觉「不像 Dashboard」 → 用布局分区 + 标题语义补强；阶段 A 再上监控卡。  
- [风险] 文档改动与代码 review 混在一起 → tasks 中文档与 UI 分批。  
- [权衡] 不改 Tab 顺序：满足「保持现序」决策，第二标签仍为媒体。

## Migration Plan

- 纯客户端 + 文档；无数据迁移。  
- 用户已有服务顺序 / 隐藏服务设置保持不变。

## Open Questions

- Dashboard 中文标题最终用「总览」还是「仪表盘」（实现时跟现有 `launcherTitle`/`tabHome` 键对齐即可）。
