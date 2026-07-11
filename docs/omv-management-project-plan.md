# OMV 8 管理端规划（独立项目）与 Proxmox 功能对标

> 目标：MyHomelab 内 OMV **极简只读**；完整管理 UI 另开项目。  
> 对标基准：本仓库已实现的 **Proxmox（PVE）** 模块深度。  
>
> ## 当前产品决策（已收窄）
>
> **MyHomelab 本期 OMV 只做一件事：硬盘健康监控。**
>
> | 做 | 不做 |
> |---|---|
> | 磁盘列表、SMART 总体状态（好/差） | SMB / NFS / WebDAV 配置与启停 |
> | 温度（SMART 属性） | 用户、共享目录、权限 |
> | 转速 RPM（机械盘；SSD 无此项则显示 —） | 文件系统创建/挂载/格式化 |
> | 型号、序列号、容量、通电时间（若 RPC 有） | ZFS 快照/销毁、磁盘 wipe |
> | 可选：重分配扇区等关键坏块指标 | 任何 `set*` / `applyChanges` |
>
> **SMB / NFS / WebDAV：MyHomelab 默认都不做。**  
> 共享协议若以后要管，放到**独立 OMV 管理项目**；本 App 用 OpenList 管文件入口即可。  
> 若以后只想「看一眼服务是否在跑」，最多加一行绿点，**不做配置**。

---

## 1. OMV 8 有没有官方文档？

**有，官方文档完整。**

| 类型 | URL | 用途 |
|---|---|---|
| **OMV 8.x 文档总入口** | https://docs.openmediavault.org/en/8.x/ | 安装、功能、管理、插件、FAQ |
| **功能概览** | https://docs.openmediavault.org/en/8.x/features.html | System / Storage / Users / Services / Diagnostics |
| **管理手册** | https://docs.openmediavault.org/en/8.x/administration/ | 日常管理（存储、服务、用户等） |
| **开发入口** | https://docs.openmediavault.org/en/8.x/development/ | 架构、插件、内部工具 |
| **`omv-rpc`（与 WebUI 同协议）** | https://docs.openmediavault.org/en/8.x/development/tools/omv_rpc.html | 官方说明：RPC = 前端实际调用的接口 |
| **RPC 实现源码** | [engined/rpc](https://github.com/openmediavault/openmediavault/tree/master/deb/openmediavault/usr/share/openmediavault/engined/rpc) | 每个 service 的 method 定义 |
| **非官方 RPC 方法表（8.x 扫描）** | https://github.com/OnlineDigital/omv-rpc-docs | 约 217 methods / 24 modules，方便检索，**非官方** |
| **社区新手指南** | https://wiki.omv-extras.org/doku.php?id=omv8:new_user_guide | OMV-Extras / 装机实操 |

### 重要结论

1. **没有**类似 Jellyfin/Immich 那种「Swagger 公网 OpenAPI 控制台」作为一等公民。
2. **有**官方开发文档：WebUI 与 `omv-rpc` 共用 **RPC（service + method + params）**。
3. 自建管理 UI 的正确姿势：  
   - 登录拿 session（与 WebUI 一致）  
   - `POST` RPC（历史上常见路径为 `/rpc.php`，以 8.x 实际 WebUI 抓包为准）  
   - 或本机 `omv-rpc -u admin 'Service' 'method' '{...}'` 做联调  
4. **MyHomelab 只读硬盘**：`Smart.enumerateDevices` / `getList` / `getAttributes` / `getInformation` 即可；不必先啃写路径。  
5. 官方 SMART 管理说明：https://docs.openmediavault.org/en/8.x/administration/storage/smart.html  

### 硬盘监控相关 RPC（只读白名单）

| Method | 用途 |
|---|---|
| `Smart.enumerateDevices` / `getList` | 支持 SMART 的磁盘列表 + 健康状态灯 |
| `Smart.getInformation` | 型号、序列号、容量、通电时间等身份信息 |
| `Smart.getAttributes` | 解析温度、转速、重分配扇区等属性 |
| `Smart.getExtendedInformation` | 可选：完整 smartctl 文本（调试用，UI 可折叠） |

**温度 / 转速从哪来：** 均在 SMART attributes 里（如 Temperature_Celsius、Spin_Up_Time / 转速相关属性因厂商而异）。SSD 通常无 RPM。  

**PVE 上的注意点（很重要）：**  
官方文档写明：对 **虚拟块设备** 不要指望真实 SMART。OMV 若跑在 PVE 虚拟机里，磁盘需 **整盘/控制器直通（passthrough）**，SMART 才是物理盘温度/转速；若是 virtio 虚拟盘，数值无意义或不可用。  

### 可选扩展（默认不做）

```bash
# 仅当以后要展示挂载容量时再用——非本期
omv-rpc -u admin 'FileSystemMgmt' 'enumerateMountedFilesystems' '{"includeroot": true}'
```

---

## 2. 产品拆分：MyHomelab vs 独立 OMV 项目

| | **MyHomelab（本仓库）** | **独立 OMV 管理项目（另开）** |
|---|---|---|
| 定位 | 家庭服务聚合入口 | OMV 专用控制台（新 UI） |
| OMV 深度 | **仅硬盘 SMART 卡片**（温/转/状态） | 共享协议、用户、存储等管理 |
| SMB/NFS/WebDAV | **不做**（文件走 OpenList） | Phase B 再考虑 |
| 危险操作 | **禁止** | 强确认 + 权限分级后可开 |
| 依赖 | 可与 Beszel 拼「系统+磁盘」Dashboard | 可只打 OMV RPC |
| 对标 | 远小于 PVE 模块；只对齐「节点磁盘健康」 | 对标 NAS 管理，不追求 PVE 全功能 |

**原则：** MyHomelab 不演变成第二个 OMV WebUI；独立项目不重复做 OpenList/Immich/Jellyfin。

---

## 3. 当前 Proxmox 已细化到哪些功能？

依据 `HomelabSwift`：`Views/Proxmox/*` + `ProxmoxAPIClient`。

### 3.1 视图清单（18 个）

| 视图 | 能力概要 |
|---|---|
| `ProxmoxDashboard` | 节点总览、资源摘要入口 |
| `ProxmoxNodeDetailView` | 单节点 CPU/内存/磁盘/负载等 |
| `ProxmoxGuestDetailView` | VM/LXC 详情、状态、Guest Agent 信息 |
| `ProxmoxClusterResourcesView` | 集群资源列表 |
| `ProxmoxStorageContentView` | 存储内容浏览/删除卷 |
| `ProxmoxNetworkView` | 节点网络 |
| `ProxmoxFirewallView` | 集群/节点/Guest 防火墙规则 |
| `ProxmoxBackupJobsView` | 备份任务列表与触发 |
| `ProxmoxGuestBackupSheet` | 单 Guest 即时备份 |
| `ProxmoxGuestCloneSheet` | 克隆 |
| `ProxmoxGuestConfigEditSheet` | 配置编辑 |
| `ProxmoxGuestMigrateSheet` | 在线/离线迁移 |
| `ProxmoxHAView` | HA 资源与组 |
| `ProxmoxPoolDetailView` | 资源池 |
| `ProxmoxServicesView` | 节点服务列表与启停 |
| `ProxmoxCephView` | Ceph 状态 / OSD / Pool |
| `ProxmoxConsoleView` | 控制台会话 |
| `ProxmoxTaskLogView` | 任务日志 |

### 3.2 API 能力分层（对标用）

| 层级 | Proxmox 已实现 | 说明 |
|---|---|---|
| **L0 连接** | 密码 Ticket + CSRF、API Token、2FA 挑战、ping、version | 完整会话模型 |
| **L1 总览** | Nodes、NodeStatus、RRD、Cluster Resources、Tasks | 监控首页核心 |
| **L2 计算资源** | VM/LXC 列表与状态、电源（启停开关机重启挂起恢复）、配置读/写、Guest Agent 多接口 | **深度管理** |
| **L3 存储** | Storage 列表、Content 列表、删除 volume、备份创建、备份 Job 触发、快照 CRUD | 含写操作 |
| **L4 网络与安全** | Networks、DNS、Firewall 读/写/开关 | 含写操作 |
| **L5 集群运维** | HA、Replication、Pools、Migrate、Create/Restore/Clone、转模板 | 高阶 |
| **L6 增值** | Ceph、APT updates、Services 控制、Console session | 运维增强 |

> 结论：当前 PVE 模块是 **监控 + 电源 + 配置 + 备份/快照 + 防火墙 + 集群运维** 的完整控制台，**远超「只读看看」**。OMV 独立项目若要对齐「同等完成度」，应分期，不要一次做满。

---

## 4. 概念对标：PVE ↔ OMV 8

> 领域不同：PVE = 虚拟化；OMV = NAS。很多能力是「角色对应」，不是 1:1 API。

| PVE 能力（本仓库） | OMV 8 对应概念 | 官方/RPC 方向 | 独立项目优先级 |
|---|---|---|---|
| Node 列表/状态 | 单机 System 信息（OMV 通常单节点） | `System.getInformation` / `getCpuStats` / `getTopInfo` | **P0 必做** |
| Node RRD 图表 | Diagnostics 图 / RRD | `RRD.getGraph` / generate | P1 |
| Cluster Resources | — | OMV 无集群资源模型 | 不做 |
| VM/LXC 电源 | — | 非 OMV 职责；你的 VM 在 PVE 上 | 归 MyHomelab PVE |
| Guest Agent 磁盘/网卡 | 文件系统 + 网络接口运行时 | `FileSystemMgmt.*`、`Network.getInformation` | P0 只读 |
| Storage 列表 | Disks / Filesystems / 挂载 | `DiskMgmt`、`FileSystemMgmt`、`FsTab` | **P0** |
| Storage Content | Shared Folders 内容 | `FolderBrowser.get`；文件真源更宜 OpenList | P2（或外链 OpenList） |
| Snapshots | ZFS/Btrfs 快照（插件或 CLI） | 核心 RPC 有限；ZFS 常靠插件/SSH | P2 谨慎 |
| Backup Jobs | rsync jobs / 插件备份 | `Rsync.*`；omv-extras 备份插件 | P2 |
| Network | 网卡/Bond/VLAN/代理 | `Network.*` | P1 只读 → P2 写 |
| Firewall | iptables 规则 | `Iptables.*` | P2 |
| Services 启停 | SMB/NFS/SSH/FTP 等 | 各 `Smb`/`Nfs`/`Ssh` + 系统服务 | P1 状态 / P2 启停 |
| Users / ACL | 用户与共享权限 | `UserMgmt.*` + share 配置 | P2 |
| HA / Migrate / Ceph | — | OMV 核心不做 | 不做（Ceph 非 OMV 主路径） |
| Console | SSH / Web 终端 | 一般不做 VNC；可「打开 OMV Web」 | P3 外链 |
| Tasks / Task Log | 后台 Exec / applyChanges | `Exec.*`、`Config.applyChangesBg` | P1 观察 apply 进度 |
| APT updates | 软件更新 | `Apt.enumerateUpgraded` / `getUpgradedList` | P1 只读列表 |
| Pool（资源池） | Shared Folder / 存储标签 | 共享目录模型 | P1 |

### 你环境上的存储语义（额外映射）

| 你的布局 | 在 OMV 里怎么看 | MyHomelab vs 独立项目 |
|---|---|---|
| `tank/media`、`tank/backup` | ZFS dataset → 文件系统/挂载 | 两边都只读展示健康与容量 |
| `apps/stack`、`apps/cloud`、`apps/dockage` | 应用数据目录；Compose 在 Dockge | Docker 交给 Dockge；OMV 只显示盘占用 |
| 共享给局域网 | SMB/NFS shares | 独立项目管；MyHomelab 可只显示「有 N 个共享」 |

---

## 5. 独立 OMV 管理项目：建议分期

项目名可自定，例如 `omv-console` / `myomv`。技术栈可与 Homelab 解耦（Swift 多端 / 纯 Web / Tauri 均可）。

### Phase A — 只读：磁盘 + 系统一眼（与 MyHomelab 同源，可先做 App 内）

- [ ] 登录 / 会话
- [ ] 磁盘 SMART 列表：状态、温度、转速、型号
- [ ] 可选：系统 uptime / 版本（轻量）
- [ ] 外链官方 WebUI

**RPC 白名单：**  
`Smart.enumerateDevices` / `getList` / `getInformation` / `getAttributes`，可选 `System.getInformation` / `noop`。

### Phase B — 共享协议（仅独立项目；MyHomelab 不做）

仅当需要替代 WebUI 管共享时：

- [ ] SMB 共享列表 / 启停状态（先只读，再写）
- [ ] NFS（可整阶段跳过，若你不用 NFS）
- [ ] WebDAV（若启用对应插件/服务）
- [ ] Shared Folders 绑定
- [ ] `Config.applyChanges` 状态机

**建议：** 若家庭只用 SMB + OpenList，独立项目也可以 **永不做 NFS/WebDAV**。

### Phase C — 存储深度（对齐 PVE 快照/备份深度，但更危险）

- [ ] ZFS 池/数据集健康（插件或受控 shell gateway）
- [ ] 快照列表 / 创建 / 回滚（极强确认）
- [ ] SMART 自检调度（只读日志 → 可选执行）
- [ ] RAID/LVM 仅展示，创建销毁默认不做

### Phase D — 网络与安全 / 插件

- [ ] 网卡配置编辑（Bond/VLAN）——对应 PVE Network + Firewall 深度
- [ ] iptables 规则管理
- [ ] 插件列表（官方 + omv-extras 元数据）
- [ ] 通知 / 邮件测试

### 刻意不做（避免和别的产品抢职责）

| 不做 | 原因 |
|---|---|
| VM/LXC | 已有 Homelab Proxmox |
| Docker Compose 全功能 | Dockge / 本仓库 Portainer 系 |
| 网盘文件浏览器 | OpenList |
| 照片/影视库 | Immich / Jellyfin |
| 夸克转存 | Quark Auto Save |

---

## 6. MyHomelab 内 OMV 最小集（已定稿）

只做硬盘健康，不做共享协议。

```text
磁盘健康卡片 / 列表
├── 每块盘：型号 · 状态灯（好/警告）
├── 温度 °C（无则 —）
├── 转速 RPM（机械盘；SSD 显示 — 或「固态」）
├── 可选副指标：通电小时、重分配扇区
└── 点进详情：关键 SMART 属性子集（非全表堆砌）
```

| 数据 | 来源 |
|---|---|
| CPU / 内存 / 网速 | **Beszel**（已有，不重复从 OMV 拉） |
| 硬盘温度 / 转速 / SMART 状态 | **OMV Smart RPC 只读** |
| 文件浏览 | **OpenList** |
| 容器 | **Dockge** |
| SMB/NFS/WebDAV | **不做**；要管再开独立 OMV 项目 |

**UI 建议：** 首页一行摘要（「3 盘正常 · 最高 42°C」）→ 点开磁盘列表。异常（高温/坏块指标）红橙标色即可。

---

## 7. 技术架构建议（独立项目）

```text
┌─────────────────┐     session/token      ┌──────────────────┐
│  OMV Console UI │ ────────────────────► │  OMV RPC Adapter │
│  (新 UI)        │ ◄──────────────────── │  (只包装 service) │
└─────────────────┘                        └────────┬─────────┘
                                                    │
                     可选只读 Gateway（ZFS/重操作）   │  http(s) rpc.php
                     ┌──────────────────┐           ▼
                     │  omv-agent       │     ┌─────────────┐
                     │  (本机、白名单)   │────►│  OMV 8 host │
                     └──────────────────┘     └─────────────┘
```

1. **Adapter 层**按 RPC service 分模块（`SystemClient`、`FileSystemClient`…），UI 不直接拼 JSON。  
2. **写操作**必须走：dirty 检测 → 用户确认 → apply 后台任务 → 轮询 `Exec`。  
3. **与 MyHomelab 共享**：仅共享「只读 DTO」设计思路，不必共享代码仓库。  
4. 鉴权：admin 与普通用户能力在服务端已有差异；客户端按角色隐藏写入口。

---

## 8. 对标完成度清单（一眼看进度）

| 维度 | PVE 本仓库 | MyHomelab OMV | 独立 OMV 项目目标 |
|---|---|---|---|
| 连接/鉴权 | 完整 | 登录测通 | 完整 session |
| 系统监控 | 节点+RRD | 交给 Beszel | 可选 Dashboard |
| **硬盘 SMART** | 节点磁盘侧有限 | **核心：温/转/状态** | 同左 + 更深属性 |
| SMB/NFS/WebDAV | 无 | **不做** | Phase B 可选；NFS 可永久跳过 |
| 存储容量/共享 | Storage+Content | 不做（OpenList） | Phase B |
| 资源控制 | VM/LXC 电源 | 无 | 服务启停 |
| 备份/快照 | 完整 | 无 | 分期 C |
| 危险写操作 | 有（多） | **永不做** | 白名单 + 确认 |

---

## 9. 建议阅读顺序（官方）

1. https://docs.openmediavault.org/en/8.x/ — 总览  
2. https://docs.openmediavault.org/en/8.x/features.html — 功能边界  
3. https://docs.openmediavault.org/en/8.x/development/howitworks.html — 配置/引擎如何工作  
4. https://docs.openmediavault.org/en/8.x/development/tools/omv_rpc.html — 用 RPC 联调  
5. GitHub `engined/rpc` 源码 — 以 8.0 分支/tag 为准看 method  
6. （可选）omv-rpc-docs 方法表做检索，实现前仍以源码为准  

---

## 10. 一句话决策

- **OMV 8 官方文档有**；硬盘监控用 **Smart RPC + 官方 SMART 说明**。  
- **MyHomelab OMV = 只监控硬盘状态 / 温度 / 转速**；**不做** SMB、NFS、WebDAV。  
- **CPU/内存/网速** 继续用 Beszel；**文件** 用 OpenList。  
- **共享协议管理** 若以后需要，只放**独立 OMV 项目**，且 NFS/WebDAV 可永久不做。  
- **PVE 直通**：物理盘 SMART 才有意义；虚拟盘不要信温度/转速。
