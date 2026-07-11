# MyHomelab 开工决策（锁定）

> 更新：2026-07 · 用户拍板 + rsync 取最简方案。  
> 状态：可据此进入实现；变更需再改本文。

---

## 1. 平台

| 项 | 决策 |
|---|---|
| **一期** | **iOS + macOS** 统一架构，同一套 Swift 业务层 |
| **UI** | 共享 ViewModel / Service / Model；布局与 Router 做平台差异（Tab / Sidebar 等） |
| **Android** | **不做**（仓库 Android 代码可保留不删，但不作为本产品路线） |
| **工程** | 以 `HomelabSwift` 为主；不因本产品去推进 `HomelabAndroid` 新功能 |

说明：当前就是「Mac for iPhone」式双端——**一套逻辑，手机和 Mac 都能用**。

---

## 2. 路径 / 目录原则（全部服务通用）

| 项 | 决策 |
|---|---|
| **总原则** | **App 不绑死任何目录、dataset、挂载名**；只调各服务 API，返回什么展示什么 |
| OpenList | list/detail/search/直链；挂载在服务端配 |
| Immich / Jellyfin | 只读 API 概览；库路径由服务自己管 |
| OMV / rsync / ZFS | 只读状态；不在 App 写路径配置（用户在 OMV/脚本侧搞定） |
| 文档里的 `tank/media` 等 | 仅作你环境的**说明示例**，**不是** App 硬编码 |

---

## 3. rsync 冷备（最简）

| 项 | 决策 |
|---|---|
| 链路 | tank 照片/备份 → **OMV 计划 rsync** → `archive/backup` |
| App 目标 | 知道「冷备是否大致正常」，不追求传输字节级日志 |
| **采用方案** | **Healthchecks 心跳（最简）** |
| 做法 | OMV rsync 任务成功结束时 `curl` 一次 Healthchecks ping URL（或已有 check） |
| App 展示 | 读 Healthchecks：上次成功时间 + 是否超时未报到 → 绿/黄/红 |
| 不做 | 解析 OMV rsync 全量日志、App 内改任务、状态 JSON Gateway（除非以后不够用） |
| 依赖 | 仓库 **已有 Healthchecks 客户端**，复用即可 |

若暂时不能改 OMV 任务钩子：首页可先只显示 **archive 相关盘 SMART + 容量**，文案写「同步状态待接入 Healthchecks」——仍算最简降级。

---

## 4. 其它已锁定（摘要）

| 主题 | 决策 |
|---|---|
| 主文件 | `tank/media` + OpenList |
| 照片 | Immich 独立 |
| OMV | 只读 SMART（温/状态；转速副信息） |
| 冷备盘 | `archive/backup` |
| SMB/NFS/WebDAV | App 不做 |
| ZFS | 快照只读摘要后置；禁止销毁/回滚 |
| Docker | Dockge 优先；摘要/外链为主 |
| 现有 30+ 服务 | 代码保留可用 |
| App 内播放器 | 不做；SenPlayer / 官方 App |
| 独立 OMV 管理 UI | 另开项目，本期不做 |

---

## 5. 实现顺序（不变）

```text
P0  配置 / Keychain / 连接状态 / Mock（Swift 双端）
P1  OpenList API 文件浏览（不绑定具体挂载路径）
P1b Quark Auto Save（可按精力）
P2  Immich
P3  Jellyfin
P4  Beszel + OMV SMART + Healthchecks(rsync) + 下载/容器摘要
P5  中文化 / 飞牛风 UI 收口
P6  iPhone + Mac 布局与真机回归（无 Android）
```

---

## 6. 验收口径（双端）

- iPhone 与 Mac **同一套** Service / 配置 / 业务模型  
- 文件：OpenList 打开即为 API 返回的根目录内容（服务端挂什么见什么）  
- 冷备：Healthchecks 显示最近成功；异常色标  
- 不引入 Android 构建为发布门槛  

---

## 7. 仍可实现时再填（不阻塞开工）

- tank 上 rsync **源**精确路径（仅文案/可选容量）  
- Healthchecks check 的 slug/UUID  
- rsync 计划周期（用于超时阈值，如 1.5× 周期）  
- SenPlayer URL scheme 真机确认  
- 服务真实 URL 只放本机配置，不进 Git  
