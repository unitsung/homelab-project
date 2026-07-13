# Comet Design Handoff

- Change: openlist-settings-i18n-polish
- Phase: design
- Mode: compact
- Context hash: fbc0b59c14ae9ca3c80e511720b19dee108fc03b597f0a731afe6553f476c2cc

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/openlist-settings-i18n-polish/proposal.md

- Source: openspec/changes/openlist-settings-i18n-polish/proposal.md
- Lines: 1-35
- SHA256: a8d4c97b2d2f16f12a9e42c90cd384e23df7f9f4d73c649335c553112160f4ca

```md
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

```

## openspec/changes/openlist-settings-i18n-polish/design.md

- Source: openspec/changes/openlist-settings-i18n-polish/design.md
- Lines: 1-65
- SHA256: 90625a44d70cbb8c9b2539eb4d244c5e1f33a45869997455832e3535761dd680

```md
## Context

Homelab iOS 应用在 fork 后持续叠加功能。本 change 对应工作区已实现、待收口的一批改动：OpenList 体验、任务 API、设置信息架构、中英仅支持语言、fork 文档。OpenSpec 刚在本仓库初始化，无既有 main specs。

约束：
- 验收以 iOS 为主（AGENTS.md 编译检查）。
- 用户声明 Android 不作为功能验收目标。
- 产品文案避免「维护者 / 继续维护」话术；上游致谢仅保留在 `NOTICE` / README，不出现在设置 UI 主路径。

## Goals / Non-Goals

**Goals:**
- 将已实现行为固化为可验收的 capability 规格与任务清单。
- 保证 iOS 编译通过；关键路径（OpenList 导航/任务/设置折叠/中英语言）可人工验收。
- 更新源与仓库文档指向本 fork。

**Non-Goals:**
- 不新增服务集成。
- 不做 Android 完整中文资源包或功能对等。
- 不在应用内强制展示 Apache 协议入口或上游作者横幅。
- 不在本阶段重写全部设置安全流实现细节（仅规范呈现与入口）。

## Decisions

1. **任务数据源：官方 OpenList Task API**  
   - 使用 `GET /api/task/{type}/undone|done` 与 cancel/retry/delete/*_some/clear_*/retry_failed。  
   - 速度字段：API `TaskInfo` 无独立 speed 时，使用 `status` 文本展示。

2. **导航语义：分层返回 vs 系统返回**  
   - 子目录：左缘手势 → 上一级；系统导航栏返回 → 离开 OpenList。  
   - 用 UIKit 禁用 interactive pop + 自定义 edge pan 实现，避免与系统 pop 冲突。

3. **音量：系统音量而非 AVPlayer.relative volume**  
   - `AVPlayer.volume = 1`；经隐藏 `MPVolumeView` 写入系统音量。  
   - iOS 27+ 使用异步 activate/deactivate，避免主线程阻塞。

4. **设置信息架构**  
   - 服务 / 外观 / 语言 / 安全 / 备份 / 开发者 / 关于。  
   - 语言与关于默认折叠，展开后操作。  
   - 版本格式：`CFBundleShortVersionString (CFBundleVersion)`。

5. **本地化范围**  
   - `Language` 枚举仅 `en` / `zh`；历史 it/fr/es/de 映射到 `en`。  
   - 删除多余 `Translations+*` 与内嵌多语言分支，降低维护成本。

6. **开源归属**  
   - 仓库保留 `LICENSE` + `NOTICE`；设置 UI 不展示「开源基础」文案与协议可点行。

## Risks / Trade-offs

- **[Risk] 任务 API 需非 guest 权限** → 失败时在 UI 展示错误；不静默吞掉。  
- **[Risk] 目录切换仍可能短暂显示旧列表** → 以「无骨架闪屏」优先；可接受短时内容滞后。  
- **[Risk] Android 语言选中文无 values-zh** → 回退英文；本 change 不验收 Android 文案。  
- **[Risk] 更新 feed 指向 fork 后需保证 `app-version.json` 可访问** → 文档与 release 流程对齐 fork 仓库。

## Migration Plan

1. 合并本工作区改动到 `main`（或独立分支后 PR）。  
2. iOS 编译检查；必要时真机验证 OpenList / 设置。  
3. 确认更新 URL 指向 `unitsung/homelab-project`。  
4. 归档 OpenSpec change。

## Open Questions

- 无阻塞问题。若后续要 Android 完整中文，另开 change。

```

## openspec/changes/openlist-settings-i18n-polish/tasks.md

- Source: openspec/changes/openlist-settings-i18n-polish/tasks.md
- Lines: 1-22
- SHA256: e6c17fcaf8f6e301cd6ed90ff7d30cf024c32244f4445443ac22affb8b01d749

```md
## 1. 规格与仓库基线

- [ ] 1.1 确认 `openspec/changes/openlist-settings-i18n-polish/` 下 proposal/design/specs/tasks 完整
- [ ] 1.2 确认 `NOTICE` 与 `README` fork 说明存在且更新 URL 指向 `unitsung/homelab-project`

## 2. OpenList 体验（已实现 → 验收勾选）

- [ ] 2.1 验收文件浏览器：子目录左滑上一级、系统返回退出 OpenList、目录切换无整页骨架
- [ ] 2.2 验收任务中心：类型/阶段、刷新/重试失败/清除/选中操作、行内删除与展开
- [ ] 2.3 验收播放器：右侧竖滑调节系统音量可达满刻度；无主线程 setActive 警告

## 3. 设置与本地化（已实现 → 验收勾选）

- [ ] 3.1 验收设置分组：服务连接实例数、外观、安全、备份、开发者
- [ ] 3.2 验收语言/关于默认折叠；版本为 `x.y.z (build)`；无协议可点行与开源基础页脚
- [ ] 3.3 验收语言仅中英；无 fr/de/it/es 选项

## 4. 构建与收尾

- [ ] 4.1 运行 iOS 编译检查并通过
- [ ] 4.2 将本 change 相关未提交改动提交到分支（提交信息清晰分组）
- [ ] 4.3 通过 Comet verify 检查清单并归档

```

## openspec/changes/openlist-settings-i18n-polish/specs/i18n-zh-en-only/spec.md

- Source: openspec/changes/openlist-settings-i18n-polish/specs/i18n-zh-en-only/spec.md
- Lines: 1-19
- SHA256: 3f640b99fa2416751fe1fab764b0acf7c1ed5ed5531eb93e571d1a0786530c4a

```md
## ADDED Requirements

### Requirement: 仅中英语言选项

iOS 应用语言设置 MUST 仅提供中文与 English 两个选项。

#### Scenario: 语言列表

- **WHEN** 用户展开设置中的语言面板
- **THEN** 选项 MUST 仅为中文与 English

### Requirement: 遗留语言映射

当用户系统或已存偏好为 it/fr/es/de 等已移除语言时，系统 MUST 回退到 English（中文系统回退到中文）。

#### Scenario: 旧偏好 fr

- **WHEN** UserDefaults 中保存的语言为 `fr`
- **THEN** 应用 MUST 以 English 启动界面语言

```

## openspec/changes/openlist-settings-i18n-polish/specs/openlist-browser-nav/spec.md

- Source: openspec/changes/openlist-settings-i18n-polish/specs/openlist-browser-nav/spec.md
- Lines: 1-28
- SHA256: 824f64c8999a883c6d9947e18e74e66f01f44841e8ed66e378c93b4263fb87f3

```md
## ADDED Requirements

### Requirement: 子目录左滑返回上一级

当用户处于 OpenList 非根路径时，系统 MUST 拦截系统 interactive pop，使左缘滑动返回上一级目录，而不是退出 OpenList 页面。

#### Scenario: 多层目录左滑

- **WHEN** 用户从根进入 `/a/b` 后从屏幕左缘右滑
- **THEN** 系统 MUST 导航到 `/a` 并重新加载该目录列表

### Requirement: 系统返回离开 OpenList

导航栏系统返回按钮 MUST 始终 pop 整个 OpenList 页面（回到首页），不得替换为「返回上一级」。

#### Scenario: 子目录点系统返回

- **WHEN** 用户在子目录点击导航栏返回
- **THEN** 系统 MUST 退出 OpenList 并回到进入前的页面

### Requirement: 目录切换无全页骨架闪屏

在已加载状态下切换文件夹时，系统 MUST NOT 将整个仪表盘切换为 skeleton 加载态；应保持布局并更新列表数据。

#### Scenario: 进入子文件夹

- **WHEN** 用户点击文件夹进入子路径且当前已是 loaded 状态
- **THEN** 系统 MUST 不展示整页骨架屏，并在请求完成后更新条目

```

## openspec/changes/openlist-settings-i18n-polish/specs/openlist-player-volume/spec.md

- Source: openspec/changes/openlist-settings-i18n-polish/specs/openlist-player-volume/spec.md
- Lines: 1-19
- SHA256: 896145d7798d696f83d58e99972a4a4a6a2bea1b52caf04f48531e9cae3743ef

```md
## ADDED Requirements

### Requirement: 手势调节系统音量

内置播放器右侧竖滑调节音量时，系统 MUST 写入系统输出音量，且 `AVPlayer` 相对增益 MUST 保持为满量程，使用户能达到系统最大音量。

#### Scenario: 拖到顶部

- **WHEN** 用户将右侧音量手势拖到顶部
- **THEN** 系统音量 MUST 可达到 100%，且 HUD 反映接近满刻度

### Requirement: 音频会话不阻塞主线程

播放器激活 / 停用音频会话时，系统 MUST 使用异步 API 或后台线程执行 `setActive`，避免在主线程同步阻塞。

#### Scenario: 打开播放器

- **WHEN** 用户打开内置播放器开始播放
- **THEN** 系统 MUST 成功配置 playback 类别并激活会话，且不在主线程执行阻塞式 `setActive`

```

## openspec/changes/openlist-settings-i18n-polish/specs/openlist-tasks/spec.md

- Source: openspec/changes/openlist-settings-i18n-polish/specs/openlist-tasks/spec.md
- Lines: 1-38
- SHA256: 56a3829ba5a19a20742799dced4a2b175e7445366ed8159cd531a213fbe2d9f3

```md
## ADDED Requirements

### Requirement: 任务列表按类型与阶段加载

系统 MUST 通过 OpenList 官方任务 API 按任务类型与阶段（进行中 / 已完成）加载任务列表，并展示名称、状态、进度与 `status` 文本。

#### Scenario: 查看复制进行中任务

- **WHEN** 用户打开任务中心并选择类型「复制」与阶段「进行中」
- **THEN** 系统 MUST 请求 `GET /api/task/copy/undone` 并渲染返回任务的进度与状态

#### Scenario: 切换到已完成

- **WHEN** 用户将阶段切换为「已完成」
- **THEN** 系统 MUST 请求对应类型的 `.../done` 并刷新列表

### Requirement: 任务操作

系统 MUST 支持刷新、重试失败、清除已结束、清除成功、以及选中项的重试/删除/取消（依阶段）；MUST 支持单行删除、失败重试与展开详情。

#### Scenario: 删除已完成任务

- **WHEN** 用户在已完成列表对某任务点击删除
- **THEN** 系统 MUST 调用 `POST /api/task/{type}/delete?tid=` 并刷新列表

#### Scenario: 批量删除选中

- **WHEN** 用户勾选多个任务并点击删除选中
- **THEN** 系统 MUST 调用 `POST /api/task/{type}/delete_some` 且 body 为 tid 数组

### Requirement: 进行中自动刷新

当用户停留在「进行中」阶段时，系统 SHOULD 周期性静默刷新任务列表（约 2–3 秒）。

#### Scenario: 轮询进行中

- **WHEN** 任务中心打开且阶段为进行中
- **THEN** 系统 MUST 在页面未离开时持续刷新进度，直至用户离开或切换阶段

```

## openspec/changes/openlist-settings-i18n-polish/specs/settings-ux/spec.md

- Source: openspec/changes/openlist-settings-i18n-polish/specs/settings-ux/spec.md
- Lines: 1-51
- SHA256: b7ffc6ab8fa45d102ad11b394756180e928923a5c3956ca843cd240c8bb8b7e4

```md
## ADDED Requirements

### Requirement: 设置分组结构

设置页 MUST 按常见结构分组呈现：服务连接、外观、语言、安全、备份、开发者、关于。

#### Scenario: 打开设置

- **WHEN** 用户进入设置页
- **THEN** 上述分组 MUST 可见且顺序合理

### Requirement: 语言与关于默认折叠

语言与关于面板 MUST 默认折叠；展开后才显示完整控件。折叠标题行 MUST 展示当前摘要（语言名 / 版本号）。

#### Scenario: 默认折叠

- **WHEN** 用户刚进入设置页
- **THEN** 语言选项列表与关于详情 MUST 默认不展开

#### Scenario: 展开语言

- **WHEN** 用户点击语言折叠标题
- **THEN** 系统 MUST 展开中文 / English 勾选列表

### Requirement: 版本展示格式

关于中的版本 MUST 展示为 `营销版本 (Build)`，即 `CFBundleShortVersionString (CFBundleVersion)`。

#### Scenario: 版本标签

- **WHEN** 用户展开关于
- **THEN** 版本行 MUST 类似 `1.6.2 (39)` 的形式

### Requirement: 关于内容范围

关于展开后 MUST 包含版本、源代码入口、检查更新；MUST NOT 展示可点击的 Apache 协议行；MUST NOT 展示「维护者」或「开源基础」类页脚文案。

#### Scenario: 无协议可点行

- **WHEN** 用户展开关于
- **THEN** 界面 MUST NOT 提供跳转到 Apache 协议页的主路径入口

### Requirement: 服务连接入口

服务连接入口 MUST 展示说明文案，并在存在实例时显示实例数量。

#### Scenario: 有实例时

- **WHEN** 用户已配置至少 1 个服务实例
- **THEN** 服务连接行 MUST 显示实例数量徽章

```
