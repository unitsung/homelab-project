## 1. 文档对齐

- [x] 1.1 更新 `docs/myhomelab-roadmap.md`：取消 P5 为待执行阶段；平台表述改为统一 iOS
- [x] 1.2 更新 `docs/decisions.md`（如有冲突段）：与统一 iOS、P5 取消一致

## 2. 标签与文案

- [x] 2.1 调整第一标签 / 总览标题本地化（中英），体现 Dashboard / 服务总览语义
- [x] 2.2 确认 Tab 顺序仍为：总览 → 媒体 → 书签 → 设置，书签可进入

## 3. Home 总览布局

- [x] 3.1 梳理 `HomeView` 标题区 / 服务网格分区并优化间距与层级；footer 去掉与连接数徽章重复的噪音
- [x] 3.2 检查已配置服务入口与空态在 iPhone 上的可读性
- [x] 3.3 避免引入废弃 API

## 4. MVP 状态摘要条

- [x] 4.1 在标题区下增加 OverviewStatusStrip：可达 Beszel → CPU/内存类摘要
- [x] 4.2 可达 Portainer（或 Dockhand/Dockmon/Komodo 降级）→ 运行/总容器摘要
- [x] 4.3 无上述数据源时不伪造指标（隐藏或引导文案）
- [x] 4.4 与现有可见性/刷新生命周期对齐；失败时不崩溃

## 5. 验收

- [x] 5.1 iOS 编译检查（本 change 触达 Swift/文档时执行 compile）
- [x] 5.2 对照 `home-dashboard-overview` spec 做手动验收清单勾选说明（含摘要条场景）
