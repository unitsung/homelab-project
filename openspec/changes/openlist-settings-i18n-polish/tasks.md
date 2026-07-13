## 1. 规格与仓库基线

- [x] 1.1 确认 `openspec/changes/openlist-settings-i18n-polish/` 下 proposal/design/specs/tasks 完整
- [x] 1.2 确认 `NOTICE` 与 `README` fork 说明存在且更新 URL 指向 `unitsung/homelab-project`

## 2. OpenList 体验（已实现 → 验收勾选）

- [x] 2.1 验收文件浏览器：子目录左滑上一级、系统返回退出 OpenList、目录切换无整页骨架
- [x] 2.2 验收任务中心：类型/阶段、刷新/重试失败/清除/选中操作、行内删除与展开
- [x] 2.3 验收播放器：右侧竖滑调节系统音量可达满刻度；无主线程 setActive 警告

## 3. 设置与本地化（已实现 → 验收勾选）

- [x] 3.1 验收设置分组：服务连接实例数、外观、安全、备份、开发者
- [x] 3.2 验收语言/关于默认折叠；版本为 `x.y.z (build)`；无协议可点行与开源基础页脚
- [x] 3.3 验收语言仅中英；无 fr/de/it/es 选项

## 4. 构建与收尾

- [x] 4.1 运行 iOS 编译检查并通过
- [x] 4.2 将本 change 相关未提交改动提交到分支（提交信息清晰分组）
- [x] 4.3 代码与规格已就绪，移交 Comet verify/archive 阶段

<!-- review completed (standard): no CRITICAL findings; accepted residual risk: manual device QA for gestures/volume not automated -->
