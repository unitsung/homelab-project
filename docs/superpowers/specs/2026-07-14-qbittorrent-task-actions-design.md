---
comet_change: qbittorrent-task-actions
role: technical-design
canonical_spec: openspec
---

# qBittorrent 任务添加与操作技术设计

## 背景

`QbittorrentAPIClient` 已有列表、传输信息、暂停/恢复/删除等能力，**缺少** `torrents/add`。`QbittorrentDashboard` 行内 `Menu` 已有暂停/恢复/删除，但无添加入口；「删除任务+文件」无二次确认；qBittorrent 5.x 可能将 pause/resume 改为 stop/start，需兼容回退。

Canonical：`openspec/changes/qbittorrent-task-actions/specs/qbittorrent-task-management/spec.md`。

## 目标

1. 支持通过 **magnet / http(s) URL** 添加任务。
2. 单任务与全局暂停/恢复在主流 qB 4.x/5.x 上可用（pause↔stop、resume↔start 回退）。
3. 删除区分仅任务 vs 任务+文件；**仅后者**二次确认。
4. 添加与操作有成功/失败反馈并刷新列表。

## 非目标

- `.torrent` 文件导入（一期不做）
- 保存路径 / 分类 / 标签完整选择 UI
- 全局偏好、限速深度设置、RSS
- 首页聚合下载卡片

## 架构（路径 A：最小增量）

```
QbittorrentDashboard
  ├── toolbar / header: + Add → Sheet (URLs)
  ├── row Menu: pause|resume, recheck, reannounce, delete, delete+files
  └── performTorrentAction → client + actionMessage + refresh

QbittorrentAPIClient
  ├── addTorrents(urls:)
  ├── pause*/resume* with stop/start fallback
  └── deleteTorrent (unchanged)
```

## API

### 添加

```swift
func addTorrents(urls: String) async throws
// POST /api/v2/torrents/add
// application/x-www-form-urlencoded: urls=<newline or \n separated>
```

经 `requestVoidWithSessionRefresh` / 现有 form 引擎，与 pause 一致。

### 暂停/恢复兼容

对单任务与 all：

1. 先请求 `/api/v2/torrents/pause` 或 `resume`
2. 若失败且像 404/方法不可用（按现有 `APIError` 可辨路径判断），再试 `stop` / `start`
3. 第二次失败则抛出原错误或聚合错误

实现可放在 client 私有 `postTorrentControl(primary:fallback:hashes:)`，避免 View 分叉。

## UI

1. **添加入口**：Dashboard 工具栏或列表区上方明显 `+` / 本地化「添加任务」。
2. **Sheet**：多行 `TextEditor` 或 `TextField`；占位说明 magnet 与 http(s)；提交调用 `addTorrents`；空/非法前端校验（`magnet:` 前缀或 `http://`/`https://`）。
3. **删除+文件**：`confirmationDialog` 确认后再 `deleteFiles: true`。
4. **仅删任务**：保持菜单直接执行。
5. **反馈**：沿用 `actionMessage` + `performTorrentAction`；失败走 `state = .error` 或更轻量 banner（与现有一致优先）。

## 本地化

新增中英键（命名示例，实现时对齐 `Translations` / `ArrStrings` 现有风格）：

- 添加任务标题、占位、提交、非法链接、添加成功

## 测试策略

- iOS compile（AGENTS.md）
- 可选：URL 校验纯函数单元测试
- 手动（有实例）：添加 magnet、暂停/恢复、两种删除、失败提示

## 风险

| 风险 | 缓解 |
|------|------|
| CSRF/会话过期 | 现有 session refresh |
| 仅 URL 不够 | 非目标声明；二期再上文件 |
| stop/start 判定误伤 | 仅在明确失败后再回退，成功路径不双发 |

## 任务映射

对应 `tasks.md`：API add + 兼容 → UI Sheet/确认 → 本地化/测试 → 编译验收。去掉一期 `.torrent` 必做项。
