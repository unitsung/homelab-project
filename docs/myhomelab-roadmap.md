# MyHomelab 后续开发计划（执行版）

> 来源：用户提供的统一家庭资源入口计划 + API 文档补充。  
> 状态：决策已锁定，见 [`decisions.md`](./decisions.md)。  
> 约束：NAS 为 PVE 上 **OMV 8.0 + ZFS**；优先只读监控与服务聚合；禁止 OMV 配置写入、磁盘操作、ZFS 删除等高风险能力。  
> 产品决策：现有 Portainer / Proxmox / Pi-hole 等 **全部保留可用**；Docker 管理目标栈为 **Dockge**（非 Portainer 优先）。  
> **平台：iOS + macOS 统一架构；Android 不做。所有服务：App 只调 API、不绑死目录/路径。rsync 冷备用 Healthchecks 最简监控。**

## 总目标

把现有 Homelab Dashboard 收敛为 **iPhone + Mac** 统一架构的家庭服务控制台（Android 不在本产品路线）：

| 能力 | 本期 |
|---|---|
| qBittorrent 任务 | 已有，保持不回归 |
| OpenList 文件/网盘 | **已完成一期**（见 Phase 1） |
| Quark Auto Save（夸克自动转存） | 新增 |
| Immich 照片库概览 | 新增 |
| Jellyfin 影视库概览 | 新增 |
| OMV 8 硬盘 SMART（温/转/状态）+ Beszel 系统监控 | 新增 / 复用 Beszel；**不做** SMB/NFS/WebDAV |
| Dockge 容器/Stack 管理 | 新增（Socket.IO，见下文风险） |
| App 内媒体播放器 | **已完成基础版**（AVPlayer；MKV 等走外链 Infuse/VLC/SenPlayer） |
| OMV 配置修改 / 磁盘 / ZFS 管理 | 不做 |
| Docker 任意删除/创建 Compose（无确认） | 不做 |

推荐顺序：

```text
P0  网络层复用、新服务配置、连接状态、Mock 约定     ← 部分完成（OpenList 相关已落地）
P1  OpenList 文件浏览、直链、播放、基础文件操作     ← **已完成**
P1b Quark Auto Save 任务列表 / 添加任务 / 手动执行
P2  Immich 照片概览
P3  Jellyfin 影视概览
P4  OMV 8 只读 + Beszel + Dockge 监控/管理首页
P5  中文化、飞牛风 UI
P6  iPhone + Mac 布局与真机回归（无 Android）
```

每阶段验收：**可独立运行、可配置真实服务、单服务失败不影响其他模块、保留 Mock 供 UI 开发**。

---

## 官方 / 项目 API 文档索引

执行实现时以这些为权威来源（先读文档再写 client）：

| 服务 | 文档 | 备注 |
|---|---|---|
| **OpenList** | [fox.oplist.org](https://fox.oplist.org/) | Apifox 导出的 OpenAPI；含认证、FS 等。兼容 AList 系接口习惯 |
| **Quark Auto Save** | [DeepWiki API Endpoints](https://deepwiki.com/Cp0204/quark-auto-save/3.3-api-endpoints) · [源码 SKILL.md](https://github.com/Cp0204/quark-auto-save/blob/main/skills/quark-auto-save/SKILL.md) | Flask REST；**token 必须放 query** |
| **Jellyfin** | [api.jellyfin.org](https://api.jellyfin.org/) | 官方 OpenAPI |
| **Immich** | [api.immich.app/endpoints](https://api.immich.app/endpoints) | 官方 endpoint 索引 |
| **OpenMediaVault 8** | [omv-rpc 工具说明](https://docs.openmediavault.org/en/stable/development/tools/omv_rpc.html) · [OMV 8.x RPC 方法表](https://github.com/OnlineDigital/omv-rpc-docs) | 版本锁定 **8.0**；Web 前端同走 RPC |
| **Dockge** | [louislam/dockge](https://github.com/louislam/dockge) · [API 讨论 #161](https://github.com/louislam/dockge/discussions/161) | **无官方 REST**；UI 走 **Socket.IO** |
| **Beszel** | 仓库已有 `BeszelAPIClient` | 实时 CPU/内存/网络首选 |
| **qBittorrent** | 仓库已有 `QbittorrentAPIClient` | 下载摘要与任务页 |

### OpenList 接入要点

文档站点：https://fox.oplist.org/

- 认证：`POST /api/auth/login`，body `{ username, password, otp_code? }`，返回 JWT `data.token`。
- 后续请求：`Authorization` 头携带 token（文档 security 说明为 JWT；实现时对照 Apifox 示例，注意是否带 `Bearer ` 前缀）。
- 业务上沿用 AList/OpenList FS 能力：目录 list、get、search、`raw_url` 直链等（具体 path 以 fox.oplist.org 中 FS 分组为准）。
- App 配置：`Base URL` + Token（可登录换 token，或用户粘贴长期 token）。
- 直链只在「播放 / 复制链接」时请求，避免列表滚动刷签名 URL。

### Quark Auto Save 接入要点

文档：https://deepwiki.com/Cp0204/quark-auto-save/3.3-api-endpoints

| Endpoint | Method | 用途 |
|---|---|---|
| `/data` | GET | 配置 + `tasklist` + `api_token` |
| `/update` | POST | 更新配置（含整表替换 tasklist） |
| `/api/add_task` | POST | 添加任务（`taskname` / `shareurl` / `savepath`） |
| `/task_suggestions` | GET | 资源搜索 `?q=&d=` |
| `/get_share_detail` | POST | 分享链接文件树 |
| `/get_savepath_detail` | GET | 夸克盘保存路径内容 |
| `/run_script_now` | POST | 立即执行；**SSE** 日志流 |
| `/delete_file` | POST | 删云盘文件（危险，默认不做或二次确认） |

**硬约束：**

- Token **必须**在 URL query：`?token=xxx`；放 body 会被服务端忽略。
- Token 只存 Keychain，拼 query 时注意日志脱敏（URL 不能进 debug 明文）。
- 删除任务需 `GET /data` 后过滤 `tasklist` 再 `POST /update`，无单独 delete-task API。
- 与 OpenList/Jellyfin 联动：QAS 插件侧常见 `alist_strm_gen` / emby 匹配；App 内可做「添加任务 → 转存完成后在 OpenList/Jellyfin 打开」的弱联动，不强制同事务。

### Jellyfin 接入要点

文档：https://api.jellyfin.org/

- 配置：Base URL + 用户 Access Token（或用户名密码换 token，实现时二选一）。
- 本期：Views / Resume / Latest / 库列表 / 海报；点击跳转官方 App 或 Web。
- Header 习惯：`X-Emby-Token` / `Authorization: MediaBrowser Token=...`（以 OpenAPI 为准）。
- 不与 Jellystat 混用 UI；Jellystat 可保留为可选分析入口。

### Immich 接入要点

文档：https://api.immich.app/endpoints

- 配置：Base URL + API Key（`x-api-key`）。
- 只读权限建议：`asset.read`、`asset.view`、`album.read`、`server.statistics`、`server.storage`。
- 首页：照片/视频总量、库占用、最近缩略图、相册网格；跳转 Immich App/Web。

### OpenMediaVault 8.0 接入要点（已收窄）

- 目标版本：**OMV 8.0**；官方文档：https://docs.openmediavault.org/en/8.x/  
- SMART 管理说明：https://docs.openmediavault.org/en/8.x/administration/storage/smart.html  
- **MyHomelab 本期只做硬盘监控**：状态、温度、转速（及可选坏块相关属性）。
- **明确不做**：SMB / NFS / WebDAV 配置或状态管理（共享协议以后若需要，放到独立 OMV 管理项目）。
- **只读 RPC 白名单**：
  - `Smart.enumerateDevices` / `getList`
  - `Smart.getInformation` / `getAttributes`
  - 可选测活：`System.noop` 或 `System.getInformation`
- **禁止**：一切 `set*`、`wipe`、`create`、`umount`、`applyChanges`、服务启停、用户/共享改写。
- **PVE 注意**：OMV 在虚拟机内时，磁盘需物理直通，SMART 温度/转速才可信；virtio 虚拟盘无效。
- CPU/内存/网速仍以 **Beszel** 为准，不从 OMV 重复拉系统指标。

### Dockge 接入要点（重要）

- 用户栈：**Dockge**（`apps/dockage` 存储布局侧），不是 Portainer 优先。
- 官方 **没有公开 REST API**（维护者与社区长期讨论中，见 [Discussion #161](https://github.com/louislam/dockge/discussions/161)）。
- Web UI 协议：**Socket.IO**（`login` / `loginByToken` + JWT；业务经 `agent` 事件代理到 endpoint）。
- 仓库已有 Portainer / Dockhand / Dockmon / Komodo，**全部保留**；新增 `ServiceType.dockge` 作为本环境默认 Docker 入口。

**推荐实现策略（分档）：**

| 档位 | 能力 | 方式 | 风险 |
|---|---|---|---|
| A 只读摘要（P4 优先） | Stack 数量、运行/停止摘要 | 自建轻量 sidecar 读 Docker/`compose` 目录，或复用社区 [dockge-status](https://github.com/DarkenLight/dockge-status) 类方案 | 低 |
| B 原生管理 | Stack 列表、start/stop/restart、看 compose | 在 App 内实现 Socket.IO client，对齐 Dockge 前后端事件 | 中高，协议随版本变 |
| C 外链 | 「在 Dockge 中打开」 | `SFSafariView` / 系统浏览器打开 Base URL | 最低 |

**本期建议：** P4 先做 **A + C**（首页摘要 + 跳转 Dockge）；B 作为后续「Dockge 原生控制」专项，需单独评估 Socket.IO 与鉴权。  
**禁止：** 把 Docker Socket 直接暴露给公网/客户端。

---

## 与仓库现状的差距（重要）

本仓库**不是**「仅有 qBittorrent 基础任务页」的空项目，而是已具备完整多服务仪表盘的 fork。

### 已存在、可直接复用

| 计划项 | 现状 |
|---|---|
| `APIClient` / 统一网络层 | `HomelabSwift/Homelab/Networking/APIClient.swift`（`BaseNetworkEngine`） |
| `APIError` | `Networking/APIError.swift`（含超时/401/网络本地化） |
| Keychain | `Services/KeychainService.swift` + `ServiceStateV2` |
| 服务配置模型 | `ServiceConnection` / `ServiceInstance` / `ServiceType` |
| 设置与多实例 | `Stores/ServicesStore.swift` + Settings UI |
| 测试连接 | 各 client 的 `ping()` / `authenticate` |
| qBittorrent | `Networking/Qbittorrent/*` + `Views/Qbittorrent/*` |
| Beszel 监控 | 完整 Dashboard + API client |
| Portainer / Docker 相关 | 已有（**保留**；用户默认用 Dockge） |
| DesignSystem 玻璃卡片等 | `DesignSystem/*` |
| 中英文等多语言 | `Localization/Translations*.swift`（非 xcstrings） |

### 计划写了但当前没有 / 已补齐

| 计划项 | 现状 |
|---|---|
| OpenList | **已有** `Networking/OpenList` + `Views/OpenList` + 登录/配置 |
| Quark Auto Save | 无 |
| Immich | 无 |
| 原生 Jellyfin 媒体库 | 无（仅有 Jellystat 分析） |
| OMV 8 RPC 只读 | 无 |
| Dockge | 无（且需 Socket.IO 或 sidecar） |
| `ServiceConnectionStatus` 统一枚举 | **已有** `Models/ServiceConnectionStatus.swift`（OpenList 路径先落地） |
| 面向 Preview 的 Mock Service 体系 | 基本无 |
| `Features/` 目录重构 | 现为 `Networking/` + `Views/` + `Models/` |
| 飞牛风统一首页聚合 | 现为多服务入口列表 |

### 现有多服务策略

**默认不删除** Portainer、Proxmox、Pi-hole 等模块；只新增目标服务。Docker 管理 UX 上优先 Dockge 入口。

### 目录策略

```text
HomelabSwift/Homelab/
├── Networking/<Service>/     # API client（与现有一致）
├── Models/<Service>/         # DTO / 业务模型
├── Views/<Feature>/          # SwiftUI
└── （可选）Features/<Name>/  # 仅新模块若需要完整 Feature 包
```

P0 不强制全仓搬家。待 1–2 个新 Feature 稳定后再渐进迁移。

---

## 开发原则（执行约束）

### 统一服务层

- 禁止在 SwiftUI `View` 中直接请求服务接口。
- 禁止硬编码 IP、端口、账号、Token、测试 URL。
- 使用现有分层：`APIClient / Store configure → ViewModel(或 Dashboard state) → View`。
- 新模块必须支持 Mock，无 NAS 可 Preview。
- 不修改现有 qBittorrent 可用逻辑；只在必要时抽复用点。
- Dockge 若走 Socket.IO：单独 `DockgeSocketClient`，不要塞进 `BaseNetworkEngine` 的纯 HTTP 假设。

### 配置与凭据

目标配置集：

```text
OMV 地址（+ 会话凭据，只读 RPC）
Beszel 地址
OpenList 地址 + Token
Quark Auto Save 地址 + Token（query token）
Immich 地址 + API Key
Jellyfin 地址 + Access Token
Dockge 地址 + 用户名/密码（或 JWT）
qBittorrent 地址（沿用现有）
```

要求：

- 地址格式 `http(s)://host[:port]`，不强制末尾 `/`。
- Token/API Key/密码只进 Keychain，不进 UserDefaults / 源码 / 日志 / Git。
- QAS 请求拼 `?token=` 时，日志必须脱敏。
- 每个服务可独立「测试连接」；成功显示版本/服务名。

建议新增 `ServiceType`：

```text
openlist
quarkAutoSave   // 或 quark_auto_save
immich
jellyfin
omv
dockge
```

---

## Phase 0：基础对齐（校准后）

### 目标

在不破坏现有服务的前提下，为新模块打齐配置、连接状态、Mock 约定。

### 任务

- [x] ~~从零新建 APIClient / Keychain~~（已有）
- [ ] 盘点并文档化：硬编码 URL / 凭据出现位置（测试数据除外）
- [ ] **不删除** Portainer 等；文档标明「Docker 默认入口为 Dockge」
- [x] 新增统一 `ServiceConnectionStatus`（未配置 / 连接中 / 已连接 / 认证失败 / 连接失败）
- [x] 扩展 `ServiceType`：`openlist`（其余 `quarkAutoSave` / `immich` / `jellyfin` / `omv` / `dockge` 待做）
- [x] 登录/配置 UI 支持 OpenList 字段与「测试连接」
- [ ] 约定 Mock 协议与 Preview 注入方式
- [x] 确认 qBittorrent 仍走统一 `BaseNetworkEngine`（回归验证）
- [ ] 可选：`testConnection()` 返回服务名/版本字符串

### 验收

- 修改服务地址后无需改 View
- Token 不出现在 Git / 日志 / UserDefaults
- qBittorrent 任务页不回归
- 新服务均可从设置页单独测试连接（骨架可先 Mock 成功路径）

---

## Phase 1：OpenList 文件与网盘 ✅

文档：https://fox.oplist.org/  
**状态：2026-07-11 一期已交付（iOS）。**

### 已完成范围

- [x] 配置 OpenList 地址 + 用户名密码 / Token；连通性测试（JWT 无 Bearer 前缀）
- [x] 根目录 / 进入 / 返回 / 面包屑；服务端挂什么见什么
- [x] 文件列表：名称、大小、修改时间、类型图标；缩略图（`thumb`）或图标兜底
- [x] 预览页：图片缩放、文本/Markdown/HTML、PDF；媒体封面 + 播放入口
- [x] 直链：`/d…?sign=` 播放与复制（不用 CDN `raw_url` 外开）
- [x] 外链播放：SenPlayer / nPlayer / VLC / Infuse / Safari（文字列表 + URL Scheme）
- [x] App 内播放器（Infuse 风格）：自动播放、侧滑亮度/音量、倍速、字幕/音轨、本地字幕、横竖屏；MKV 等走外链专业播放器
- [x] 关键字搜索（当前目录 scope）
- [x] 基础文件操作：新建文件夹、上传、下载/分享、重命名、移动、复制、删除、解压
- [x] 文本类预览与保存编辑
- [x] 多语言文案（EN/ZH + 其它语言桩）

### 仍暂不做 / 后续

- 网盘账号与存储源管理（仍在 OpenList Web 后台）
- 复杂上传队列 / 断点续传
- App 内 FFmpeg 硬解 MKV（需 KSPlayer/VLCKit，体积大）
- 完整 Mock Preview 体系
- 批量下载整文件夹、外挂字幕自动匹配增强

### 关键路径

```text
Networking/OpenList/OpenListAPIClient.swift
Models/OpenList/OpenListModels.swift
Utilities/ExternalPlayerRouter.swift
Views/OpenList/
  OpenListFileBrowserView.swift
  OpenListFilePreviewView.swift
  OpenListMediaPlayerView.swift
  OpenListPlayerPickerView.swift
  OpenListFolderPickerView.swift
```

### 验收（已满足）

能浏览约定目录树、多层返回、取直链、外链/内置播放、搜索、基础文件操作可用。

---

## Phase 1b：Quark Auto Save

文档：https://deepwiki.com/Cp0204/quark-auto-save/3.3-api-endpoints

### 范围（建议）

- 配置 Base URL + Token；`GET /data` 测通
- 任务列表（`tasklist`）：名称、savepath、runweek、是否 `shareurl_ban`
- 添加任务：`POST /api/add_task`（粘贴夸克分享链接 + 目标路径）
- 可选：`GET /task_suggestions` 搜索资源
- 可选：`POST /get_share_detail` 预览分享内容后再确认添加
- 手动执行：`POST /run_script_now`（先做 fire-and-forget；SSE 日志流可作为二期）
- 失效分享提示：检测 `shareurl_ban`

### 暂不做

- 默认不开放 `/delete_file`
- 不在 App 内完整编辑 crontab / 复杂 magic_regex 编辑器（可后续）
- 不替代 OpenList 文件浏览

### 模块建议

```text
Features/QuarkAutoSave/  或  Views/QuarkAutoSave/ + Networking/QuarkAutoSave/
├── Models/QuarkTask.swift
├── Services/QuarkAutoSaveAPIClient.swift
├── Services/MockQuarkAutoSaveService.swift
├── ViewModels/QuarkTasksViewModel.swift
└── Views/QuarkTasksView.swift / AddQuarkTaskView.swift
```

### 验收

- 能列出任务、添加任务、看到失败/封禁状态
- Token 仅 query 且不进日志
- 服务不可用时不影响 OpenList / 下载页

---

## Phase 2：Immich 照片库概览

文档：https://api.immich.app/endpoints

只做入口与概览，不复刻官方客户端。只读 API Key。  
范围：连接测试、总量、存储、最近照片、相册列表与缩略图、跳转 Immich App/Web。  
不做：备份、上传、删除编辑、人物/地图/时间线复刻、本地双向同步。

---

## Phase 3：Jellyfin 影视库

文档：https://api.jellyfin.org/

只接 Jellyfin；抽象 `MediaRepository`，日后 Emby 另做 Adapter。  
范围：媒体库、继续观看、最近添加、海报与基础元信息、跳转 App/Web；可选从 OpenList 跳 SenPlayer。  
不做：App 内播放/转码、字幕音轨、进度上报、扫描刮削、Emby 双适配、内嵌 WebView 伪装原生页。

---

## Phase 4：OMV 8 / Beszel / Dockge

| 数据 | 首选 | 备注 |
|---|---|---|
| CPU / 内存 / 网络 | Beszel | 已有客户端 |
| **硬盘温度 / 转速 / SMART 状态** | **OMV 8 Smart RPC 只读** | 磁盘健康 |
| **主文件 `tank/media`** | **OpenList** | 文件 Tab，不在首页堆目录 |
| **照片库** | **Immich**（独立库，非 media） | 照片 Tab |
| **备份目录 + rsync 冷备** | **Healthchecks 心跳（最简）** | OMV rsync 成功后 ping；App 显示最近成功/超时；见 `decisions.md` |
| **ZFS 快照摘要** | 只读 Gateway（`zfs list -t snapshot`） | 最近快照时间；**禁止**创建/回滚/删除 |
| media/backup 容量 | FS 枚举或 Gateway | 可选进度条 |
| SMB / NFS / WebDAV | **不做** | 文件入口用 OpenList |
| Docker Stack 摘要 | **Dockge** | 默认不走 Portainer |
| 下载摘要 | qBittorrent | 已有 |
| 夸克转存摘要 | Quark Auto Save `/data` | 任务数 / 最近失败 |

存储拓扑详见：[`storage-topology.md`](./storage-topology.md)。

聚合在 `DashboardRepository` 内合并，禁止 View 内乱 `async let`。  
单服务失败仅该卡片异常。自动刷新 10–15s，离开页面停止。

### Dockge 本期范围

- [ ] 配置 Dockge 地址 + 登录凭据
- [ ] 连通性（能 login 或 sidecar ping）
- [ ] 首页：Stack 运行/停止数量摘要
- [ ] 「在 Dockge 中打开」
- [ ] （可选后续）Stack 列表 + start/stop（Socket.IO 专项）

### 暂不做

- OMV 用户、共享、RAID、磁盘配置写入
- ZFS 创建/销毁/快照/回滚
- 无确认的 Stack 删除
- Docker Socket 直暴露给客户端
- 容器 Shell / 远程终端

### 首页模型（保持）

```swift
struct DashboardSnapshot: Codable, Sendable {
    let generatedAt: Date
    let system: SystemMetrics
    let disks: [DiskHealth]           // OMV SMART
    let storagePools: [StoragePool]   // media / backup / 冷备容量（可选）
    let rsyncJobs: [RsyncJobStatus]   // 最近成功时间、失败原因
    let zfsSnapshots: [ZfsSnapshotSummary] // 每数据集最近快照
    let containers: ContainerSummary
    let downloads: DownloadSummary
    let quarkTasks: QuarkTaskSummary?
}
```

---

## Phase 5：中文化与飞牛风 UI

- 用户可见文案走现有 `Translations` 体系（渐进）
- 产品名保留英文：OpenList、Immich、Jellyfin、Docker、ZFS、qBittorrent、Dockge、Quark Auto Save
- Container→容器，Pool→存储池，Volume→数据卷，Stack→栈（或「Compose 栈」）
- 浅色大留白卡片；深色模式不阻塞

---

## Phase 6：iPhone + Mac 适配与发布

- **统一架构**：共享模型 / Service / ViewModel；平台差异只在 Router、系统 API、布局
- macOS：宽屏 Dashboard、Sidebar、快捷键（菜单栏状态可后置）
- iOS：Tab（主页/文件/下载/媒体/设置）、下拉刷新、URL Scheme、SideStore 回归
- **Android：不做**（不作为发布门槛）
- Socket.IO（Dockge）若做需验证后台挂起与重连

---

## 风险与安全红线

1. **不写 OMV 配置、不删 ZFS、不操作磁盘**（OMV 曾因降内存异常）。
2. Token 永不入 Git / 日志 / 崩溃上报明文；**QAS query token 尤其注意 URL 日志**。
3. Docker：**默认 Dockge**；不把 Docker Socket 暴露给客户端；破坏性操作二次确认。
4. Dockge **无 REST**：实现成本高于 Immich/Jellyfin，勿在 P1 阻塞文件入口。
5. 每个 Phase 可独立交付，避免多 Agent 互相阻塞。

---

## 下一刀

1. ~~P1：OpenList 全链路~~ **已完成**  
2. P1b：Quark Auto Save 任务（[DeepWiki](https://deepwiki.com/Cp0204/quark-auto-save/3.3-api-endpoints)）  
3. P0 补齐：其余 `ServiceType`（immich / jellyfin / omv / dockge）+ Mock 约定  
4. P2/P3：Immich / Jellyfin 只读  
5. P4：OMV 8 只读 + Beszel 聚合 + Dockge 摘要/外链（Socket.IO 原生管理后置）
