---
comet_change: openlist-settings-i18n-polish
role: technical-design
canonical_spec: openspec
archived-with: 2026-07-13-openlist-settings-i18n-polish
status: final
---

# 技术设计：OpenList 体验、设置 UX 与中英本地化收尾

## 1. 概述

本 change 收口工作区已实现功能，固化为 OpenSpec 规格与可验收任务，而非从零实现。规范源为 `openspec/changes/openlist-settings-i18n-polish/specs/*/spec.md`。

## 2. 架构与模块边界

| 模块 | 路径 | 职责 |
|------|------|------|
| 文件浏览 | `OpenListFileBrowserView` | 路径状态导航、edge-swipe 上一级、任务入口 |
| 任务中心 | `OpenListTasksView` + API | 官方 task API 列表与操作 |
| 播放器 | `OpenListMediaPlayerView` | 系统音量、异步音频会话 |
| 设置 | `SettingsView` + `SettingsStore` | 信息架构、折叠语言/关于、版本标签、更新源 |
| i18n | `Language` + `Translations+{Chinese,English}` | 仅中英 |
| 归属 | `LICENSE` / `NOTICE` / `README` | 法律声明，非 App 主 UI |

## 3. 关键实现细节

### 3.1 任务中心

- 类型：`copy` / `move` / `upload` / `offline_download` / `offline_download_transfer` / `decompress` / `decompress_upload`
- 阶段：`undone` / `done` 对应 API 路径段
- 批量：`cancel_some` / `retry_some` / `delete_some`，body 为 JSON 字符串数组
- 进行中轮询约 2.5s

### 3.2 导航

- `shouldCaptureEdgeSwipeForFolderUp`：非根或搜索中拦截 system interactive pop
- 系统返回按钮不隐藏：始终 pop OpenList
- 目录切换：`navigate` 保持 `.loaded`，避免 `ServiceDashboardLayout` 骨架

### 3.3 音量与会话

- `player.volume = 1.0`；`OpenListSystemVolumeWriter` + 隐藏 `MPVolumeView`
- iOS 27+：`activate` / `deactivate` 异步；iOS 26：`setActive` 在 detached task

### 3.4 设置 UX

- 语言 / 关于：`@State is*Expanded = false`，`collapsibleHeader` 展开
- 版本：`appVersionLabel = "\(version) (\(build))"`
- 关于内无 Apache 可点行、无 credits 页脚

### 3.5 本地化

- `Language.resolve`：`zh*` → zh，其余 → en
- 删除 FR/DE/IT/ES 翻译文件与 Pangolin/ArrStrings 多语言分支

## 4. 测试策略

| 层级 | 内容 |
|------|------|
| 编译 | Homelab iOS Debug iphoneos，`CODE_SIGNING_ALLOWED=NO` |
| 手工 | Spec 场景：返回、任务操作、音量、设置折叠、语言选项 |
| 回归 | 首页进 OpenList、设置备份/安全入口仍可用 |

## 5. 交付与提交

1. 自 `main` 拉分支（如 `feat/openlist-settings-i18n-polish`）
2. 逻辑提交建议：
   - `feat(openlist): navigation, tasks, player volume`
   - `feat(settings): redesign about/language panels`
   - `chore(i18n): zh/en only; docs NOTICE`
3. 通过 Comet verify 后归档

## 6. 非目标

- Android 完整中文 strings
- 新服务集成
- App 内上游作者营销展示
