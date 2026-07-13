---
change: openlist-settings-i18n-polish
design-doc: docs/superpowers/specs/2026-07-13-openlist-settings-i18n-polish-design.md
base-ref: 2d975c085555bef8219172f20de9262fd15646d7
---

# 实施计划：openlist-settings-i18n-polish

## 背景

代码与规格已就绪（方案 A）。本计划以验收、编译与提交收尾为主。

## 任务映射

### 批次 1：规格与文档基线
- 对应 tasks 1.1–1.2
- 确认 OpenSpec 产物与 NOTICE/README

### 批次 2：OpenList 验收
- 对应 tasks 2.1–2.3
- 导航 / 任务中心 / 播放器音量（对照 delta specs）

### 批次 3：设置与 i18n 验收
- 对应 tasks 3.1–3.3
- 折叠面板、版本格式、仅中英

### 批次 4：构建与提交
- 对应 tasks 4.1–4.3
- iOS 编译；创建 feature 分支；逻辑提交；进入 verify

## 执行顺序

1. iOS 编译检查
2. 勾选已满足的验收任务（基于代码审查 + 编译）
3. 创建分支并提交
4. 进入 Comet verify

## 不做

- 不重写已实现模块
- 不强制 Android 构建
