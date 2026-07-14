## 1. API

- [x] 1.1 实现 `torrents/add`（`urls`：magnet / http(s)），复用会话刷新
- [x] 1.2 pause/resume 与 qB 5.x stop/start 兼容回退（单任务 + all）

## 2. UI

- [x] 2.1 Dashboard 增加明显的「添加任务」入口与表单 Sheet
- [x] 2.2 校验空/非法输入与错误提示
- [x] 2.3 「删除任务+文件」二次确认；确认单任务暂停/恢复/仅删任务可发现
- [x] 2.4 操作成功/失败反馈 + 列表刷新

## 3. 本地化与测试

- [x] 3.1 补充中英文字符串（添加、占位、错误、确认）
- [x] 3.2 （可选）URL 校验纯函数单元测试 — 提供 `normalizedTorrentURLs` 静态方法，未单独加 XCTest（tdd_mode: direct）

## 4. 验收

- [x] 4.1 iOS 编译检查 — BUILD SUCCEEDED (Xcode-beta)
- [x] 4.2 对照 `qbittorrent-task-management` spec 手动验收说明
  <!-- Manual: with qB instance — add magnet/URL; pause/resume; delete vs delete+files confirm cancel; error path -->

<!-- review_mode: standard
Light review: no CRITICAL. Notes: fallback only on 404/405; add uses form urls; sheet closes on success.
-->
