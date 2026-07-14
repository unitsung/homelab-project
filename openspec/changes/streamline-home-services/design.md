# 设计：精简首页服务列表

## 实现方案

修改 `ServiceType.swift` 中的两个静态属性：

1. **`homeServices`**：改为显式返回 9 个服务，不再依赖 `mediaServices` 做减法
2. **`mediaServices`**：移除已被纳入首页的 qbittorrent/radarr/sonarr/lidarr，仅保留其余纯媒体类服务（jellyseerr/prowlarr/bazarr/gluetun/flaresolverr）

不删除枚举 case，用户的已有服务实例不受影响——只是首页不再展示未列入 `homeServices` 的服务类型。
