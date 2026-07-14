## Why

qBittorrent 在 App 内目前以查看进度与列表为主；用户需要完整的日常任务管理（尤其是**添加任务**）。API 层已有暂停/恢复/删除，但缺少添加能力，且需保证这些操作在 UI 上可发现、可用、有反馈。

## What Changes

- 支持 **添加任务**（至少：磁力/HTTP(S) 链接；`.torrent` 文件若实现成本可控则一并支持）。
- 保证 **暂停、恢复、删除**（含是否删文件）在列表中可操作、有成功/失败反馈，并刷新列表状态。
- 核对 qBittorrent WebUI API 版本差异（如 pause/stop、resume/start 命名），保证主流版本可用。
- 新代码避免废弃 API；不抬升部署目标。

## Capabilities

### New Capabilities

- `qbittorrent-task-management`: 下载任务的添加、暂停、恢复、删除及列表反馈。

### Modified Capabilities

- （无）

## Impact

- **iOS**：`Networking/Qbittorrent/*`、`Views/Qbittorrent/QbittorrentDashboard.swift`、相关本地化与（如有）单元测试。
- **非目标**：qBittorrent 全局偏好设置编辑、RSS、分类/标签完整管理、首页聚合下载卡片（属后续 Dashboard A）。
