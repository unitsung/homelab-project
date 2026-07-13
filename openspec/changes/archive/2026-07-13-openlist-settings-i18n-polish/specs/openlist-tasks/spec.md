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

当用户停留在「进行中」阶段时，系统 MUST 周期性静默刷新任务列表（约 2–3 秒）。

#### Scenario: 轮询进行中

- **WHEN** 任务中心打开且阶段为进行中
- **THEN** 系统 MUST 在页面未离开时持续刷新进度，直至用户离开或切换阶段
