## Context

- `QbittorrentAPIClient` 已实现：`getTorrents`、`getTransferInfo`、`pauseTorrent` / `resumeTorrent`、`pauseAll` / `resumeAll`、`deleteTorrent`、`recheck` / `reannounce`。
- **缺少** `torrents/add`（磁力/URL/文件）。
- `QbittorrentDashboard` 行内 Menu 已有暂停/恢复/删除；用户感知仍为「只能看进度」，主因是无添加入口，且操作可能不够显眼或受 API 版本（v4 pause vs v5 stop）影响。
- 约束：不抬部署目标；新代码不用废弃 API。

## Goals / Non-Goals

**Goals:**

- 添加任务（至少链接/磁力）。
- 暂停、恢复、删除可用且可发现，成功/失败有反馈并刷新列表。
- 兼容常见 qB WebUI API 行为差异。

**Non-Goals:**

- 编辑全局偏好、限速面板深度设置、RSS、完整分类管理 UI。
- 首页聚合下载摘要（Dashboard 阶段 A）。

## Decisions

1. **添加任务入口**  
   - Dashboard 工具栏或列表区明显 `+` / 「添加」→ Sheet：粘贴 magnet / http(s) URL。  
   - API：`POST /api/v2/torrents/add`（`urls` 表单字段）。  
   - `.torrent` 文件：若 `fileImporter` + multipart 成本可控则做；否则 tasks 标为可选增强。

2. **暂停/恢复兼容**  
   - 优先现有 pause/resume；若 404/失败，回退 `stop`/`start`（qB 5.x）。  
   - 备选：启动时探测 version 再选路径。

3. **删除确认**  
   - 仅删任务 vs 删任务+文件：保持现有两条菜单；破坏性操作使用 `role: .destructive` 与确认（若当前无确认可补）。

4. **反馈**  
   - 沿用 `actionMessage` + 错误 `LoadableState` / 行内禁用 `isRunningTorrentAction`；添加成功后 silent/full 刷新列表。

## Risks / Trade-offs

- [风险] WebUI CSRF / Cookie 会话过期 → 沿用现有 `requestWithSessionRefresh`。  
- [风险] 仅支持 URL 不满足部分用户 → 文档与 UI 标明；可选文件导入。  
- [权衡] 不做完整分类/保存路径选择 → 使用服务端默认路径，降低第一期复杂度。

## Migration Plan

- 无破坏性数据迁移。  
- 旧版本客户端仅只读列表；升级后出现添加入口。

## Open Questions

- 是否一期必须支持 `.torrent` 文件（默认：链接优先，文件可选）。
