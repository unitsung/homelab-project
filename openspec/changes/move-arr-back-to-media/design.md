# 设计：将 ARR 服务移回 mediaServices

## 实现方案

修改 `ServiceType.swift`：

1. `homeServices`：从当前 9 个服务中移除 radarr、sonarr、lidarr、qbittorrent，仅保留 truenas、openlist、proxmox、beszel、portainer
2. `mediaServices`：恢复 radarr、sonarr、lidarr、qbittorrent
