# 提案：将 ARR 服务移回 mediaServices

## 动机

用户反馈 radarr、sonarr、lidarr、qbittorrent 不需要在首页展示，应保持为媒体类服务独立管理。

## 目标

将这 4 个服务从 `homeServices` 中移除，重新加入 `mediaServices`。首页仅保留 5 个核心服务：truenas、openlist、proxmox、beszel、portainer。

## 范围

- **仅 iOS**：修改 `HomelabSwift/Homelab/Models/ServiceType.swift`
- 不涉及 Android
