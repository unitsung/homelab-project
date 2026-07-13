## Why

本会话已在 iOS 上落地一批体验与产品化改动（OpenList 浏览/播放/任务、设置页重做、仅中英本地化、fork 归属文档），但尚未纳入统一变更管理与验收清单。需要把这些改动收口为可验证、可归档的 OpenSpec change，避免工作区长期脏状态、范围不清。

## What Changes

- **OpenList 文件浏览**：目录切换更平滑；子目录左滑返回上一级；系统返回仍退出 OpenList；任务中心入口与任务列表/操作。
- **OpenList 播放器**：音量改为系统音量控制；音频会话异步激活，避免主线程卡顿警告。
- **OpenList 任务中心**：对接官方 `/api/task/{type}/…`；支持进行中/已完成、刷新、重试失败、清除、多选删除/重试/取消、行内删除/展开；默认轮询进行中任务。
- **全局 TabBar**：取消滚动自动收缩，固定底部导航。
- **本地化**：iOS 仅保留中文 / 英语；移除法/德/意/西翻译与相关分支（含 Pangolin 内嵌多语言、ARR ArrStrings 等）。
- **设置页**：结构按常见设置分组重做；服务连接带实例数；外观合并主题与图标；语言列表勾选且默认折叠；关于默认折叠，展示版本号 `x.y.z (build)`、源代码、检查更新；去掉维护者话术、可点协议行与页脚「开源基础」文案。
- **仓库文档**：新增 `NOTICE`；`README` 改为 fork 说明与许可证指引；更新检查 URL 指向 `unitsung/homelab-project`。
- **Android（附带清理）**：语言枚举缩为 en/zh；删除 `values-de/es/fr/it`（用户声明 Android 不作为验收重点，仅允许清理项进入本 change）。

## Capabilities

### New Capabilities

- `openlist-tasks`: OpenList 任务中心（列表、进度、单任务与批量操作）。
- `openlist-browser-nav`: 文件浏览器导航与返回手势语义。
- `openlist-player-volume`: 内置播放器系统音量与音频会话行为。
- `settings-ux`: 设置页信息架构、折叠面板、版本展示与产品文案定位。
- `i18n-zh-en-only`: 应用语言仅中英。

### Modified Capabilities

- （无既有 main specs；本仓库 OpenSpec 首次初始化。）

## Impact

- **iOS 代码**：`OpenList*` 视图与 API、`SettingsView`、`SettingsStore`、`ContentView`、`Translations*`、`PangolinDashboard` 多语言清理、`project.pbxproj`。
- **仓库根**：`NOTICE`、`README.md`、`openspec/` 结构。
- **Android**：仅语言枚举与多余 `values-*` 删除，不做功能验收。
- **行为**：OpenList 返回手势、任务操作、设置布局、语言选项减少、更新源域名变更。
