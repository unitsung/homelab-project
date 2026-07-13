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
