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
