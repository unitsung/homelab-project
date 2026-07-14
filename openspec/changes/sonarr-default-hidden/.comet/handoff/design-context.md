# Comet Design Handoff

- Change: sonarr-default-hidden
- Phase: design
- Mode: compact
- Context hash: 23e64d7668e8f046b1a83cf2d05a52b424575387476ae17bcface11747033fb1

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/sonarr-default-hidden/proposal.md

- Source: openspec/changes/sonarr-default-hidden/proposal.md
- Lines: 1-25
- SHA256: fe81fbaa82470f4b089f521fe8f6c106d9692f1ecd32296cd7399190c687efa5

```md
## Why

Sonarr（电视剧自动追更，*arr 栈）在国内目标用户中使用频率低，默认出现在媒体服务列表会增加噪音。需要默认隐藏/降权，同时保留代码与配置能力，避免误删有用集成。

## What Changes

- **默认隐藏或降权** Sonarr 在媒体服务列表/推荐露出中的位置（新装或默认设置下不突出）。
- 用户仍可在设置中 **重新显示/启用** Sonarr。
- **不删除** Sonarr 客户端、Dashboard 与登录配置代码。
- 新代码避免废弃 API；不抬升部署目标。

## Capabilities

### New Capabilities

- `media-service-visibility`: 媒体服务（至少 Sonarr）的默认可见性与用户覆盖规则。

### Modified Capabilities

- （无）

## Impact

- **iOS**：`ServiceType` / 媒体服务列表过滤、`SettingsStore.hiddenServices`（或等价机制）、`MediaDashboardView` 与设置中「隐藏服务」相关 UI/默认值。
- **非目标**：移除 Sonarr 代码；改变 Radarr/Lidarr 默认策略（除非实现时复用同一套可见性机制）。

```

## openspec/changes/sonarr-default-hidden/design.md

- Source: openspec/changes/sonarr-default-hidden/design.md
- Lines: 1-48
- SHA256: 32944e733e02ea262c23804655b21acc29ddc160a7019866338ab1eb9fb0a7ae

```md
## Context

- 媒体列表通过 `settingsStore.hiddenServices` 过滤：`MediaDashboardView` 已支持隐藏任意媒体 `ServiceType`。
- 默认 `hiddenServices` 来自 UserDefaults，空则全部显示，故 Sonarr 默认可见。
- 决策：默认隐藏/降权 Sonarr；不删代码；用户可再打开。

## Goals / Non-Goals

**Goals:**

- 新用户或未显式配置过可见性时，Sonarr **默认不出现**在媒体网格常用露出中。
- 设置中可取消隐藏，之后行为与其它服务一致。
- 已主动配置/显示过 Sonarr 的用户不应被粗暴「再次强制隐藏」而不知情（见决策）。

**Non-Goals:**

- 删除 `SonarrDashboard` / API / 登录流。
- 默认隐藏 Radarr/Lidarr（除非复用机制时不改变其默认值）。
- 改首页 Home 服务集合。

## Decisions

1. **复用 `hiddenServices`，加「默认隐藏集合」**  
   - 引入默认隐藏 rawValue 集合（至少 `sonarr`）。  
   - 首次启动：若 UserDefaults 无 `homelab_hidden_services` 键，则初始化为默认隐藏集合。  
   - 若键已存在：尊重用户已存集合（不覆盖），避免升级后抢走已显示 Sonarr 的用户。  
   - 备选：每次强制 merge sonarr → 简单但伤害老用户，否决。

2. **「降权」= 默认隐藏，而非仅排序到最后**  
   - 与现有隐藏开关一致，实现成本低、语义清晰。

3. **设置入口**  
   - 沿用现有隐藏服务 / 媒体排序 UI，确保 Sonarr 在「已隐藏」中可恢复。

## Risks / Trade-offs

- [风险] 老用户 UserDefaults 为空数组已写入 → 不会自动隐藏；可接受（仅新默认）。  
- [风险] 用户找不到 Sonarr → 设置/媒体「显示隐藏服务」路径需可发现。  
- [权衡] 不删代码：包体积几乎不变，维护面保留。

## Migration Plan

- 仅影响「从未写过 hiddenServices」的安装；已有键不迁移。  
- 可选：文档一句说明默认隐藏 Sonarr。

## Open Questions

- 是否对「空数组已持久化」的安装做一次性默认 merge（默认不做）。

```

## openspec/changes/sonarr-default-hidden/tasks.md

- Source: openspec/changes/sonarr-default-hidden/tasks.md
- Lines: 1-17
- SHA256: 316d0f5d95de7f70446a0adf6ce22e5d83aea342667762621426b883741bb14e

```md
## 1. 默认可见性

- [ ] 1.1 在 `SettingsStore`（或等价处）定义默认隐藏集合（含 `sonarr`）
- [ ] 1.2 仅在「从未保存过 hiddenServices」时应用默认集合；已有键不覆盖
- [ ] 1.3 确认媒体网格过滤仍走 `hiddenServices`

## 2. 设置可恢复

- [ ] 2.1 确认设置/媒体排序或隐藏 UI 可取消隐藏 Sonarr
- [ ] 2.2 必要时补充文案说明「部分服务默认隐藏」

## 3. 验收

- [ ] 3.1 新装路径：媒体列表默认无 Sonarr
- [ ] 3.2 取消隐藏后可再配置进入 Sonarr
- [ ] 3.3 模拟「已有 hiddenServices」升级：偏好不被强制改写
- [ ] 3.4 iOS 编译检查

```

## openspec/changes/sonarr-default-hidden/specs/media-service-visibility/spec.md

- Source: openspec/changes/sonarr-default-hidden/specs/media-service-visibility/spec.md
- Lines: 1-37
- SHA256: 7d6559f4b8325f12dd799605349b671ed02676ea35ee1b0d256a64392c9b42ff

```md
## ADDED Requirements

### Requirement: Sonarr 默认不可见

在用户尚未自定义媒体服务可见性的默认情况下，Sonarr MUST 不出现在媒体标签的服务网格常用列表中。

#### Scenario: 新安装默认隐藏 Sonarr

- **WHEN** 用户为新安装（无已保存的隐藏服务偏好）打开媒体标签
- **THEN** Sonarr 入口 MUST NOT 出现在默认可见的媒体服务列表中

### Requirement: 用户可恢复显示 Sonarr

系统 MUST 允许用户通过设置（或等价的服务可见性 UI）取消隐藏 Sonarr，使其重新出现在媒体列表。

#### Scenario: 取消隐藏后可见

- **WHEN** 用户将 Sonarr 从隐藏集合中移除
- **THEN** 媒体标签中 MUST 再次显示 Sonarr 入口（在服务类型排序规则下）

### Requirement: 不删除 Sonarr 能力

系统 MUST 保留 Sonarr 的配置、登录与 Dashboard 实现；默认隐藏 MUST NOT 等同于移除功能代码。

#### Scenario: 恢复后可配置使用

- **WHEN** 用户重新显示 Sonarr 并完成实例配置
- **THEN** 用户 MUST 能进入 Sonarr 相关界面（与隐藏前能力等价，允许无回归）

### Requirement: 尊重已有可见性偏好

若用户设备上已存在已保存的隐藏服务偏好，系统 MUST NOT 在升级时静默覆盖该偏好以强制隐藏 Sonarr。

#### Scenario: 升级保留用户设置

- **WHEN** 用户升级应用且本地已有隐藏服务偏好数据
- **THEN** 系统 MUST 继续使用已保存偏好，MUST NOT 强制改写为默认集合

```
