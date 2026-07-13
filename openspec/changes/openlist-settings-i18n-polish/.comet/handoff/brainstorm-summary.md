# Brainstorm Summary

- Change: openlist-settings-i18n-polish
- Date: 2026-07-13
- Status: 已确认

## 确认的技术方案

**方案 A：现状落地 + 验收勾选 + 分支收尾**

- 不重写已实现模块（OpenList 浏览/播放/任务、设置 UX、中英 i18n、NOTICE/README）
- 对照 OpenSpec delta specs 做验收勾选
- iOS 编译检查必过
- 提交：独立分支 + 1–3 个逻辑清晰提交
- Android 语言清理可随仓库提交，但不作为验收重点

## 关键取舍与风险

- 目录切换短时显示旧列表可接受（优先无骨架闪屏）
- 任务 API 需权限；失败需 UI 可见
- 应用内不展示上游致谢；归属仅在 LICENSE/NOTICE/README

## 测试策略

1. iOS xcodebuild 编译（iphoneos，无签名）
2. 人工验收：OpenList 返回语义、任务操作、系统音量、设置折叠与版本格式、语言仅中英
3. 不强制 Android 构建

## Spec Patch

无
