## ADDED Requirements

### Requirement: 手势调节系统音量

内置播放器右侧竖滑调节音量时，系统 MUST 写入系统输出音量，且 `AVPlayer` 相对增益 MUST 保持为满量程，使用户能达到系统最大音量。

#### Scenario: 拖到顶部

- **WHEN** 用户将右侧音量手势拖到顶部
- **THEN** 系统音量 MUST 可达到 100%，且 HUD 反映接近满刻度

### Requirement: 音频会话不阻塞主线程

播放器激活 / 停用音频会话时，系统 MUST 使用异步 API 或后台线程执行 `setActive`，避免在主线程同步阻塞。

#### Scenario: 打开播放器

- **WHEN** 用户打开内置播放器开始播放
- **THEN** 系统 MUST 成功配置 playback 类别并激活会话，且不在主线程执行阻塞式 `setActive`
