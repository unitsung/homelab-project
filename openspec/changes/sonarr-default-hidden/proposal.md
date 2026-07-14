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
