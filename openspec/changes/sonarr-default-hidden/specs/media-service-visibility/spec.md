## ADDED Requirements

### Requirement: Sonarr 默认不可见

在用户尚未自定义媒体服务可见性的默认情况下，Sonarr MUST 不出现在媒体标签的服务网格常用列表中。

#### Scenario: 新安装默认隐藏 Sonarr

- **WHEN** 用户为新安装（无已保存的隐藏服务偏好）打开媒体标签
- **THEN** Sonarr 入口 MUST NOT 出现在默认可见的媒体服务列表中

### Requirement: 用户可恢复显示 Sonarr

系统 MUST 允许用户通过设置（或等价的服务可见性 UI）取消隐藏 Sonarr，使其重新出现在媒体列表。

#### Scenario: 取消隐藏后可见

- **WHEN** 用户将 Sonarr 从隐藏集合中移除
- **THEN** 媒体标签中 MUST 再次显示 Sonarr 入口（在服务类型排序规则下）

### Requirement: 不删除 Sonarr 能力

系统 MUST 保留 Sonarr 的配置、登录与 Dashboard 实现；默认隐藏 MUST NOT 等同于移除功能代码。

#### Scenario: 恢复后可配置使用

- **WHEN** 用户重新显示 Sonarr 并完成实例配置
- **THEN** 用户 MUST 能进入 Sonarr 相关界面（与隐藏前能力等价，允许无回归）

### Requirement: 尊重已有可见性偏好

若用户设备上已存在已保存的隐藏服务偏好，系统 MUST NOT 在升级时静默覆盖该偏好以强制隐藏 Sonarr。

#### Scenario: 升级保留用户设置

- **WHEN** 用户升级应用且本地已有隐藏服务偏好数据
- **THEN** 系统 MUST 继续使用已保存偏好，MUST NOT 强制改写为默认集合
