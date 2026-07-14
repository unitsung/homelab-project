## ADDED Requirements

### Requirement: 默认第一标签为服务总览 Dashboard

应用启动后，用户 MUST 默认落在第一标签；该标签 MUST 呈现为服务总览（Dashboard）语义，而不是模糊的「启动器」表述。Tab 文案 MUST 使用中文「总览」/ 英文「Overview」一类总览用语（不得再使用含糊的「首页」作为唯一语义）；大标题 MUST 表达「服务总览 / Service Overview」。

#### Scenario: 冷启动进入总览

- **WHEN** 用户打开 App 且未处于需拦截的引导/更新强制流程
- **THEN** 选中第一标签，并显示服务总览主界面

#### Scenario: 文案语义为总览

- **WHEN** 用户查看第一标签名称与总览页大标题（中文或英文界面）
- **THEN** 文案表达服务总览语义（中文含「总览」；英文为 Overview / Service Overview 一类），而非仅品牌名启动器

### Requirement: 标签顺序保持不变

系统 MUST 保持标签顺序为：服务总览 → 媒体 → 书签 → 设置。

#### Scenario: 底部导航顺序

- **WHEN** 用户查看底部 Tab 栏
- **THEN** 四个标签按「总览、媒体、书签、设置」顺序排列，书签仍可进入

### Requirement: 总览布局可读

服务总览 MUST 具备清晰的标题区与服务入口网格；在已配置服务时 MUST 能浏览并进入已连接服务。页内 MUST NOT 用与标题区连接计数重复的页脚再次强调同一数字作为主要信息。

#### Scenario: 已配置服务可进入

- **WHEN** 用户至少配置了一个首页类服务实例
- **THEN** 总览中可见对应入口，点击后进入该服务界面

#### Scenario: 无服务时空态可理解

- **WHEN** 用户尚未配置任何首页类服务
- **THEN** 总览展示可理解的空态或引导，且不崩溃

### Requirement: 可选状态摘要条（依赖已配置服务）

当用户已配置可用于系统或容器摘要的服务时，服务总览 MUST 在标题区附近提供只读状态摘要；系统 MUST NOT 在未配置相应服务时展示伪造的 Docker 或系统占用数据。

#### Scenario: 无监控/容器数据源时不伪造指标

- **WHEN** 用户未配置可达的 Beszel，且未配置可达的 Portainer（及约定的容器管理降级源）
- **THEN** 总览不展示虚假的 CPU/内存/容器运行数；可隐藏摘要条或仅显示引导添加服务的说明

#### Scenario: 已配置 Beszel 时显示系统摘要

- **WHEN** 用户至少有一个可达的 Beszel 实例
- **THEN** 总览状态摘要展示该数据源可得的 CPU 与内存占用类信息

#### Scenario: 已配置容器管理服务时显示容器摘要

- **WHEN** 用户至少有一个可达的 Portainer 实例（若无 Portainer，实现可使用已约定的 Dockhand/Dockmon/Komodo 降级源）
- **THEN** 总览状态摘要展示运行中容器数与总容器数（或等价摘要）

### Requirement: 路线图取消 P5 并统一平台表述

项目文档 MUST 标明 P5（中文化/飞牛风专项）已取消，且产品平台为统一 iOS 架构（非独立 macOS 路线、Android 非产品路线）。

#### Scenario: 路线图与决策一致

- **WHEN** 读者打开 `docs/myhomelab-roadmap.md` 与 `docs/decisions.md` 相关章节
- **THEN** 不再将 P5 列为待执行阶段，平台描述与统一 iOS 决策一致
