# Comet Design Handoff

- Change: qbittorrent-task-actions
- Phase: design
- Mode: compact
- Context hash: cb91ba10cdd4681346ea0a0b3e85f14a881795f9d418129c6dd5c0bf476c4d59

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/qbittorrent-task-actions/proposal.md

- Source: openspec/changes/qbittorrent-task-actions/proposal.md
- Lines: 1-25
- SHA256: 056c451472472896730a9b9a9f7fcc524f494aa021d4177fa7225900f15d337d

```md
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

```

## openspec/changes/qbittorrent-task-actions/design.md

- Source: openspec/changes/qbittorrent-task-actions/design.md
- Lines: 1-51
- SHA256: 13e81e41d76230ac7cd3a8df542b11f031e9429e2de10d6b0b08a6f8438b1e09

```md
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

```

## openspec/changes/qbittorrent-task-actions/tasks.md

- Source: openspec/changes/qbittorrent-task-actions/tasks.md
- Lines: 1-21
- SHA256: 44a3b3d2397bf6888ee0e4bdf0e3ba26679ad726c0df7bfd98849153d1edfb85

```md
## 1. API

- [ ] 1.1 实现 `torrents/add`（`urls`：magnet / http(s)），复用会话刷新
- [ ] 1.2 pause/resume 与 qB 5.x stop/start 兼容回退（单任务 + all）

## 2. UI

- [ ] 2.1 Dashboard 增加明显的「添加任务」入口与表单 Sheet
- [ ] 2.2 校验空/非法输入与错误提示
- [ ] 2.3 「删除任务+文件」二次确认；确认单任务暂停/恢复/仅删任务可发现
- [ ] 2.4 操作成功/失败反馈 + 列表刷新

## 3. 本地化与测试

- [ ] 3.1 补充中英文字符串（添加、占位、错误、确认）
- [ ] 3.2 （可选）URL 校验纯函数单元测试

## 4. 验收

- [ ] 4.1 iOS 编译检查
- [ ] 4.2 对照 `qbittorrent-task-management` spec 手动验收说明

```

## openspec/changes/qbittorrent-task-actions/specs/qbittorrent-task-management/spec.md

- Source: openspec/changes/qbittorrent-task-actions/specs/qbittorrent-task-management/spec.md
- Lines: 1-57
- SHA256: 010fc2be5c0defecf6522dbaad7da579e9428aebd8f9ef25115c497b767bbbb6

```md
## ADDED Requirements

### Requirement: 添加下载任务

在已配置并成功连接的 qBittorrent 实例上，用户 MUST 能够通过磁力链接或 HTTP(S) 种子 URL 添加任务。一期 MUST NOT 将 `.torrent` 本地文件导入作为必达能力。

#### Scenario: 通过链接添加任务

- **WHEN** 用户打开添加任务界面并提交合法的 magnet 或种子 URL
- **THEN** 客户端向 qBittorrent 发起添加请求，成功后任务出现在列表中（或刷新后可见）

#### Scenario: 非法输入被拒绝

- **WHEN** 用户提交空内容或明显非法链接
- **THEN** 系统 MUST 拒绝提交并给出错误提示，且 MUST NOT 静默失败

### Requirement: 暂停与恢复任务

用户 MUST 能够对单个任务执行暂停与恢复；当服务端不支持 pause/resume 路径时，客户端 MUST 尝试 stop/start 等价路径。操作结果 MUST 反映到列表状态。

#### Scenario: 暂停下载中的任务

- **WHEN** 用户对非暂停任务选择暂停
- **THEN** 请求成功后该任务呈现暂停/停止态（刷新后一致）

#### Scenario: 恢复已暂停任务

- **WHEN** 用户对已暂停任务选择恢复
- **THEN** 请求成功后该任务离开暂停态（刷新后一致）

### Requirement: 删除任务

用户 MUST 能够删除任务，并区分是否同时删除磁盘文件。删除任务及文件 MUST 在执行前要求用户确认。

#### Scenario: 仅删除任务

- **WHEN** 用户选择删除任务且不删除文件
- **THEN** 任务从列表移除，且请求参数表明不删文件

#### Scenario: 删除任务及文件

- **WHEN** 用户确认删除任务并删除数据
- **THEN** 任务从列表移除，且请求参数表明删除文件

#### Scenario: 取消删除文件

- **WHEN** 用户在删除任务及文件确认框中取消
- **THEN** MUST NOT 发起删除请求

### Requirement: 操作反馈

任务操作（添加/暂停/恢复/删除）MUST 提供成功或失败的可感知反馈，且失败时 MUST NOT 假装成功。

#### Scenario: 网络失败

- **WHEN** 操作因网络或鉴权失败
- **THEN** 用户看到错误信息，列表状态与服务器一致（通过刷新或回滚感知）

```
