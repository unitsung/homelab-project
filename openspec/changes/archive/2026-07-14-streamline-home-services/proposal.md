# 提案：精简首页服务列表

## 动机

当前首页展示所有非媒体类服务（共约 28 个），对于实际使用场景来说过于冗余。用户只需要保留自己实际使用的少数核心服务。

## 目标

将首页 `homeServices` 精简为仅展示以下 9 个服务：

- truenas
- openlist
- proxmox
- beszel
- portainer
- qbittorrent
- radarr
- sonarr
- lidarr

## 范围

- **仅 iOS**：修改 `HomelabSwift/Homelab/Models/ServiceType.swift` 中 `homeServices` 和 `mediaServices` 的定义
- 不删除任何 `ServiceType` 枚举 case，保留向后兼容性（用户已添加的服务实例不受影响）
- 不涉及 Android 端
