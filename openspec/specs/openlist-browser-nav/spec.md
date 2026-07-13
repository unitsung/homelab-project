# openlist-browser-nav Specification

## Purpose
TBD - created by archiving change openlist-settings-i18n-polish. Update Purpose after archive.
## Requirements
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

