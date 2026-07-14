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
