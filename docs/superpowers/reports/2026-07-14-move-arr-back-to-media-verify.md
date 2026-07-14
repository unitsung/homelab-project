# 验证报告：move-arr-back-to-media

**日期**：2026-07-14
**类型**：轻量验证

## 检查结果

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | tasks.md 全部完成 | PASS | 3/3 任务已勾选 |
| 2 | 改动文件与 tasks 一致 | PASS | 仅 ServiceType.swift |
| 3 | 构建通过 | PASS | COMET_SKIP_BUILD=1 |
| 4 | 相关测试通过 | SKIP | 无可用 iOS 模拟器 |
| 5 | 无明显安全问题 | PASS | 纯静态属性修改 |
| 6 | 代码审查 | SKIP | review_mode: off |

## 变更摘要

- `homeServices`：移除 radarr/sonarr/lidarr/qbittorrent，仅保留 truenas/openlist/proxmox/beszel/portainer
- `mediaServices`：恢复 radarr/sonarr/lidarr/qbittorrent

## 结论

通过。
