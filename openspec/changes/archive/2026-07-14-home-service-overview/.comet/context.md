# Comet Design Handoff

- Change: home-service-overview
- Phase: design
- Mode: compact
- Context hash: 17031f409fd48cbe8e3fea7d74e534f8a220cf3e5d35798493be2950ed71d955

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/home-service-overview/proposal.md

- Source: openspec/changes/home-service-overview/proposal.md
- Lines: 1-26
- SHA256: c1b79ac470dad476f91378011f41e210d2b666baa1ba804cd48604c9da5091d8

```md
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

```

## openspec/changes/home-service-overview/design.md

- Source: openspec/changes/home-service-overview/design.md
- Lines: 1-52
- SHA256: 810a582bf9abdbbed7d345906e45930404cb51b887ef99a5c0244c4b82c6234e

```md
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

```

## openspec/changes/home-service-overview/tasks.md

- Source: openspec/changes/home-service-overview/tasks.md
- Lines: 1-27
- SHA256: dc91965ed85ac64c7b9397e56a1ae1f7e653947b3ead5242350ebc1c18b10cc9

```md
## 1. 文档对齐

- [ ] 1.1 更新 `docs/myhomelab-roadmap.md`：取消 P5 为待执行阶段；平台表述改为统一 iOS
- [ ] 1.2 更新 `docs/decisions.md`（如有冲突段）：与统一 iOS、P5 取消一致

## 2. 标签与文案

- [ ] 2.1 调整第一标签 / 总览标题本地化（中英），体现 Dashboard / 服务总览语义
- [ ] 2.2 确认 Tab 顺序仍为：总览 → 媒体 → 书签 → 设置，书签可进入

## 3. Home 总览布局

- [ ] 3.1 梳理 `HomeView` 标题区 / 服务网格分区并优化间距与层级；footer 去掉与连接数徽章重复的噪音
- [ ] 3.2 检查已配置服务入口与空态在 iPhone 上的可读性
- [ ] 3.3 避免引入废弃 API

## 4. MVP 状态摘要条

- [ ] 4.1 在标题区下增加 OverviewStatusStrip：可达 Beszel → CPU/内存类摘要
- [ ] 4.2 可达 Portainer（或 Dockhand/Dockmon/Komodo 降级）→ 运行/总容器摘要
- [ ] 4.3 无上述数据源时不伪造指标（隐藏或引导文案）
- [ ] 4.4 与现有可见性/刷新生命周期对齐；失败时不崩溃

## 5. 验收

- [ ] 5.1 iOS 编译检查（本 change 触达 Swift/文档时执行 compile）
- [ ] 5.2 对照 `home-dashboard-overview` spec 做手动验收清单勾选说明（含摘要条场景）

```

## openspec/changes/home-service-overview/specs/home-dashboard-overview/spec.md

- Source: openspec/changes/home-service-overview/specs/home-dashboard-overview/spec.md
- Lines: 1-66
- SHA256: a8f3674966b535b3ca9c3e1333bb3793abf21c9abd294deda8d92f1c18949bc4

```md
## ADDED Requirements

### Requirement: 默认第一标签为服务总览 Dashboard

应用启动后，用户 MUST 默认落在第一标签；该标签 MUST 呈现为服务总览（Dashboard）语义，而不是模糊的「启动器」表述。Tab 文案 MUST 使用中文「总览」/ 英文「Overview」一类总览用语（不得再使用含糊的「首页」作为唯一语义）；大标题 MUST 表达「服务总览 / Service Overview」。

#### Scenario: 冷启动进入总览

- **WHEN** 用户打开 App 且未处于需拦截的引导/更新强制流程
- **THEN** 选中第一标签，并显示服务总览主界面

#### Scenario: 文案语义为总览

- **WHEN** 用户查看第一标签名称与总览页大标题（中文或英文界面）
- **THEN** 文案表达服务总览语义（中文含「总览」；英文为 Overview / Service Overview 一类），而非仅品牌名启动器

### Requirement: 标签顺序保持不变

系统 MUST 保持标签顺序为：服务总览 → 媒体 → 书签 → 设置。

#### Scenario: 底部导航顺序

- **WHEN** 用户查看底部 Tab 栏
- **THEN** 四个标签按「总览、媒体、书签、设置」顺序排列，书签仍可进入

### Requirement: 总览布局可读

服务总览 MUST 具备清晰的标题区与服务入口网格；在已配置服务时 MUST 能浏览并进入已连接服务。页内 MUST NOT 用与标题区连接计数重复的页脚再次强调同一数字作为主要信息。

#### Scenario: 已配置服务可进入

- **WHEN** 用户至少配置了一个首页类服务实例
- **THEN** 总览中可见对应入口，点击后进入该服务界面

#### Scenario: 无服务时空态可理解

- **WHEN** 用户尚未配置任何首页类服务
- **THEN** 总览展示可理解的空态或引导，且不崩溃

### Requirement: 可选状态摘要条（依赖已配置服务）

当用户已配置可用于系统或容器摘要的服务时，服务总览 MUST 在标题区附近提供只读状态摘要；系统 MUST NOT 在未配置相应服务时展示伪造的 Docker 或系统占用数据。

#### Scenario: 无监控/容器数据源时不伪造指标

- **WHEN** 用户未配置可达的 Beszel，且未配置可达的 Portainer（及约定的容器管理降级源）
- **THEN** 总览不展示虚假的 CPU/内存/容器运行数；可隐藏摘要条或仅显示引导添加服务的说明

#### Scenario: 已配置 Beszel 时显示系统摘要

- **WHEN** 用户至少有一个可达的 Beszel 实例
- **THEN** 总览状态摘要展示该数据源可得的 CPU 与内存占用类信息

#### Scenario: 已配置容器管理服务时显示容器摘要

- **WHEN** 用户至少有一个可达的 Portainer 实例（若无 Portainer，实现可使用已约定的 Dockhand/Dockmon/Komodo 降级源）
- **THEN** 总览状态摘要展示运行中容器数与总容器数（或等价摘要）

### Requirement: 路线图取消 P5 并统一平台表述

项目文档 MUST 标明 P5（中文化/飞牛风专项）已取消，且产品平台为统一 iOS 架构（非独立 macOS 路线、Android 非产品路线）。

#### Scenario: 路线图与决策一致

- **WHEN** 读者打开 `docs/myhomelab-roadmap.md` 与 `docs/decisions.md` 相关章节
- **THEN** 不再将 P5 列为待执行阶段，平台描述与统一 iOS 决策一致

```
