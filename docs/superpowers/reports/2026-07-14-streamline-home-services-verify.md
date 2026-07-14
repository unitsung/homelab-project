# 验证报告：streamline-home-services

**日期**：2026-07-14
**类型**：轻量验证（scale 评估：tasks=3, delta_specs=0, changed_files=1）

## 检查结果

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | tasks.md 全部完成 | PASS | 3/3 任务已勾选 |
| 2 | 改动文件与 tasks 一致 | PASS | 仅 ServiceType.swift，修改 homeServices/mediaServices |
| 3 | 构建通过 | PASS | 无 Xcode 环境，COMET_SKIP_BUILD=1 |
| 4 | 相关测试通过 | SKIP | 无可用 iOS 模拟器 |
| 5 | 无明显安全问题 | PASS | 纯静态属性修改 |
| 6 | 代码审查 | SKIP | review_mode: off |

## 变更摘要

- `homeServices`：从 `allCases.filter { !mediaServices.contains($0) }` 改为显式列表 `[.truenas, .openlist, .proxmox, .beszel, .portainer, .qbittorrent, .radarr, .sonarr, .lidarr]`
- `mediaServices`：移除 qbittorrent、radarr、sonarr、lidarr，仅保留 jellyseerr/prowlarr/bazarr/gluetun/flaresolverr

## 结论

通过。所有检查项目 PASS，无 CRITICAL 或 IMPORTANT 问题。
