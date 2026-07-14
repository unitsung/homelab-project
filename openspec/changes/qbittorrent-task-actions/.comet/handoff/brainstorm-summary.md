# Brainstorm Summary

- Change: qbittorrent-task-actions
- Date: 2026-07-14
- Status: **已确认**

## 确认的技术方案

路径 A 最小增量：仅 magnet/URL 添加；pause/stop resume/start 回退；删文件需确认；无 .torrent。

## 关键取舍与风险

会话过期走现有 refresh；文件导入二期。

## 测试策略

iOS compile；可选 URL 校验单测；有实例手动联调。

## Spec Patch

已写：无 .torrent 必达；stop/start 回退；删文件确认与取消场景。
