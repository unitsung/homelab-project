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
