---
change: qbittorrent-task-actions
design-doc: docs/superpowers/specs/2026-07-14-qbittorrent-task-actions-design.md
base-ref: 232ef4699fb9cadcc824afd54e4d3769a7c4dce9
archived-with: 2026-07-14-qbittorrent-task-actions
---

# qBittorrent 任务添加与操作 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans or subagent-driven-development. Steps use checkbox syntax.

**Goal:** 支持 magnet/URL 添加任务，pause/resume 兼容 stop/start，删文件需确认，操作有反馈。

**Architecture:** 最小增量改 `QbittorrentAPIClient` + `QbittorrentDashboard` + ArrStrings 本地化。

**Tech Stack:** SwiftUI、现有 qB WebUI API v2 form POST。

## Global Constraints

- 语言：zh-CN 产物；UI 中英
- 一期无 `.torrent` 文件
- 不抬部署目标
- Canonical spec：`qbittorrent-task-management`

---

### Task 1: API add + pause/resume fallback

**Files:**
- Modify: `HomelabSwift/Homelab/Networking/Qbittorrent/QbittorrentAPIClient.swift`

- [x] **Step 1: 实现 addTorrents(urls:)**

`POST /api/v2/torrents/add`，body `urls`，经 `requestVoidWithSessionRefresh`。

- [x] **Step 2: 控制命令回退**

私有 helper：先 primary path，失败且 `httpError` status 为 404（或 body 暗示 not found）时用 fallback path。应用到 pause/resume 单任务与 all：`pause`→`stop`，`resume`→`start`。

- [x] **Step 3: 提交**

```bash
git commit -m "feat: add qB torrents/add and pause/stop compatibility"
```

---

### Task 2: Dashboard UI

**Files:**
- Modify: `HomelabSwift/Homelab/Views/Qbittorrent/QbittorrentDashboard.swift`
- Modify: ArrStrings in `Translations.swift` (+ chinese/english init sections for Arr)

- [x] **Step 1: 添加入口 + Sheet**

状态：`showAddSheet`、`addURLsText`、`addError`。工具栏或 filter 旁 `+`。Sheet 提交调用 `addTorrents`。

- [x] **Step 2: URL 校验**

空拒绝；每行 trim；需 `magnet:` 或 `http://`/`https://`。

- [x] **Step 3: 删文件 confirmationDialog**

`pendingDeleteHash`；destructive 菜单只设 pending；确认后 `deleteFiles: true`。

- [x] **Step 4: 本地化键 + 提交**

---

### Task 3: 验收

- [x] **Step 1: iOS compile**
- [x] **Step 2: 勾选 tasks + 提交**
