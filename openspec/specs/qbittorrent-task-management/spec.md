# qbittorrent-task-management Specification

## Purpose
TBD - created by archiving change qbittorrent-task-actions. Update Purpose after archive.
## Requirements
### Requirement: 添加下载任务

在已配置并成功连接的 qBittorrent 实例上，用户 MUST 能够通过磁力链接或 HTTP(S) 种子 URL 添加任务。一期 MUST NOT 将 `.torrent` 本地文件导入作为必达能力。

#### Scenario: 通过链接添加任务

- **WHEN** 用户打开添加任务界面并提交合法的 magnet 或种子 URL
- **THEN** 客户端向 qBittorrent 发起添加请求，成功后任务出现在列表中（或刷新后可见）

#### Scenario: 非法输入被拒绝

- **WHEN** 用户提交空内容或明显非法链接
- **THEN** 系统 MUST 拒绝提交并给出错误提示，且 MUST NOT 静默失败

### Requirement: 暂停与恢复任务

用户 MUST 能够对单个任务执行暂停与恢复；当服务端不支持 pause/resume 路径时，客户端 MUST 尝试 stop/start 等价路径。操作结果 MUST 反映到列表状态。

#### Scenario: 暂停下载中的任务

- **WHEN** 用户对非暂停任务选择暂停
- **THEN** 请求成功后该任务呈现暂停/停止态（刷新后一致）

#### Scenario: 恢复已暂停任务

- **WHEN** 用户对已暂停任务选择恢复
- **THEN** 请求成功后该任务离开暂停态（刷新后一致）

### Requirement: 删除任务

用户 MUST 能够删除任务，并区分是否同时删除磁盘文件。删除任务及文件 MUST 在执行前要求用户确认。

#### Scenario: 仅删除任务

- **WHEN** 用户选择删除任务且不删除文件
- **THEN** 任务从列表移除，且请求参数表明不删文件

#### Scenario: 删除任务及文件

- **WHEN** 用户确认删除任务并删除数据
- **THEN** 任务从列表移除，且请求参数表明删除文件

#### Scenario: 取消删除文件

- **WHEN** 用户在删除任务及文件确认框中取消
- **THEN** MUST NOT 发起删除请求

### Requirement: 操作反馈

任务操作（添加/暂停/恢复/删除）MUST 提供成功或失败的可感知反馈，且失败时 MUST NOT 假装成功。

#### Scenario: 网络失败

- **WHEN** 操作因网络或鉴权失败
- **THEN** 用户看到错误信息，列表状态与服务器一致（通过刷新或回滚感知）

