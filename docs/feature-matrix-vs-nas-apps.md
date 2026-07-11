# 功能对照：别人做了什么 → MyHomelab 能做什么

> 综合：群晖 / 威联通 / TrueNAS 生态 / Unraid / Scrutiny，以及你们已定栈（OMV8 + ZFS + OpenList + Immich + Jellyfin + qBittorrent + Beszel + Dockge + QAS）。  
> 图例：✅ 建议做 · 🟡 可选/二期 · ❌ 不做 · ⬛ 仓库已有（可复用）

---

## 总览：别人的能力地图

```text
商业 NAS 全家桶 ≈ 多 App 拼盘
┌─────────────┬─────────────┬─────────────┬─────────────┐
│ 运维监控    │ 文件/网盘   │ 照片/影视   │ 下载/备份   │
│ DS finder   │ Drive       │ Photos      │ Download    │
│ QManager    │ Qfile       │ Video       │ Hyper Bck   │
│ Unraid Rem. │             │             │             │
└─────────────┴─────────────┴─────────────┴─────────────┘
        + 专用盘健康（Scrutiny / DA Analyzer）
        + 容器/VM（部分 Unraid / 厂商套件）

MyHomelab ≈ 一块聚合壳，对接自建服务
┌──────────────────────────────────────────────────────┐
│ Dashboard：Beszel + OMV 盘 + Dockge 摘要 + 下载摘要   │
│ 文件：OpenList · 照片：Immich · 影视：Jellyfin        │
│ 下载：qBittorrent · 转存：QAS · （PVE 模块已有）      │
└──────────────────────────────────────────────────────┘
```

---

## 1. 系统 / 主机监控

| 功能 | 群晖/威联通/Unraid 等 | 我们 | 数据源 | 优先级 |
|---|---|---|---|---|
| CPU / 内存 | 都有 | ✅ | **Beszel**（已有客户端） | P4 首页 |
| 网络上下行 | 常有 | ✅ | Beszel | P4 |
| 系统温度 | 部分有 | 🟡 | Beszel 若有传感器 | 有则显示 |
| 运行时间 uptime | 常有 | ✅ | Beszel / OMV 轻量 | P4 |
| 多机/多 NAS 总览 | Active Insight、Connect | 🟡 | Beszel 多节点已有模型 | 后置 |
| 推送告警 | 官方推送很强 | 🟡 | 系统通知 / 外链 Webhook | 二期 |
| 远程开关机/休眠 | 部分有 | ❌ | 风险高（OMV 曾异常） | 不做 |

---

## 2. 硬盘 / 存储健康

| 功能 | 别人 | 我们 | 数据源 | 优先级 |
|---|---|---|---|---|
| 盘列表 + 健康色点 | 都有 | ✅ | OMV Smart RPC | **P4 核心** |
| 当前温度 | 移动端主 KPI | ✅ | SMART attributes | **P4 核心** |
| 最高盘温挂首页 | Unraid Remote | ✅ | 聚合 max | P4 |
| 转速 RPM | 桌面 SMART 有，移动少强调 | 🟡 副信息 | SMART | P4 副显示 |
| 通电小时 / 型号 / 序列号 | Overview 标准 | ✅ | Smart.getInformation | P4 详情 |
| 重分配/Pending 扇区 | Scrutiny 重点 | ✅ | 关键属性 | P4 详情 |
| 完整 SMART 表 | 第二层 | 🟡 折叠 | getAttributes | 可选 |
| 温度历史曲线 | Scrutiny 强项 | 🟡 | 需 Scrutiny 或自建时序 | 二期 |
| 跑 short/long SMART 测试 | Web 常有 | ❌ / 🟡 | 写操作边缘 | 独立 OMV 项目 |
| AI 故障预测 | QNAP DA | ❌ | 无 | 不做 |
| 卷/池容量条 | 都有 | 🟡 | FS 枚举 / zpool 网关 | 可选，非必须 |
| RAID/ZFS 创建销毁 | Web 有 | ❌ | — | 永不做 |
| SMB/NFS/WebDAV 配置 | Web 有，移动运维少做 | ❌ | — | 不做 |

---

## 3. 文件 / 网盘

| 功能 | 别人（Drive / Qfile） | 我们 | 数据源 | 优先级 |
|---|---|---|---|---|
| 目录浏览 / 面包屑 | 都有 | ✅ | **OpenList** | **P1** |
| 文件名搜索 | 都有 | ✅ | OpenList search | P1 |
| 缩略图 | 常有 | 🟡 | 列表 thumbnail / 图标兜底 | P1 |
| 直链 / 外链播放 | 部分有 | ✅ | raw_url + SenPlayer | **P1** |
| 复制链接 | 常有 | ✅ | | P1 |
| 上传 / 下载队列 | 强 | 🟡 | OpenList 上传 API | 后置 |
| 删除/移动/重命名 | 有 | ❌ 本期 | | 不做 |
| 分享链接管理 | 有 | ❌ | | 不做 |
| 网盘账号（夸克等）管理 | 厂商网盘或 AList | ❌ | 在 OpenList 服务端配 | App 不管理 |
| 夸克自动转存任务 | 少见（自建特色） | ✅ | **Quark Auto Save** | **P1b** |

---

## 4. 照片

| 功能 | 别人（Photos） | 我们 | 数据源 | 优先级 |
|---|---|---|---|---|
| 库总量 / 占用 | 有 | ✅ | Immich stats | **P2** |
| 最近照片条 | 有 | ✅ | Immich | P2 |
| 相册列表 + 缩略图 | 有 | ✅ | Immich | P2 |
| 时间线 / 人物 / 地图 | 官方很深 | ❌ | | 不做（跳原生 App） |
| 备份上传手机相册 | 核心卖点 | ❌ | | 用 Immich 官方 |
| 在 Immich 中打开 | — | ✅ | URL Scheme / Web | P2 |

---

## 5. 影视

| 功能 | 别人（Video / Infuse 生态） | 我们 | 数据源 | 优先级 |
|---|---|---|---|---|
| 媒体库入口 | 有 | ✅ | **Jellyfin** | **P3** |
| 继续观看 | 有 | ✅ | Resume | P3 |
| 最近添加 | 有 | ✅ | Latest | P3 |
| 海报 + 进度 | 有 | ✅ | | P3 |
| App 内转码播放 | 官方有 | ❌ | | 外链 Jellyfin / SenPlayer |
| 字幕/音轨/队列 | 播放器能力 | ❌ | | 不做 |

---

## 6. 下载

| 功能 | 别人（Download Station 等） | 我们 | 数据源 | 优先级 |
|---|---|---|---|---|
| 任务列表 / 状态 | 有 | ⬛ | **qBittorrent** 已有 | 保持 |
| 上下行速度摘要 | 常有 | ✅ | 首页卡片 | P4 聚合 |
| 添加种子/磁力 | 常有 | 🟡 | 现有能力可扩展 | 按需 |
| BT 客户端深度设置 | Web 有 | ❌ | | 不做 |

---

## 7. 容器 / 应用

| 功能 | 别人 | 我们 | 数据源 | 优先级 |
|---|---|---|---|---|
| 容器运行数摘要 | Unraid 等有 | ✅ | **Dockge** 摘要路径 | P4 |
| Stack 列表 / 启停 | 部分有 | 🟡 | Dockge Socket.IO 难 | 后置 |
| 完整 Compose 编辑 | 少（Web） | ❌ | | 外链 Dockge |
| Docker 删除/创建 | 有也危险 | ❌ | | 不做 |

仓库已有 Portainer/Dockmon 等可保留，**默认 UX 指向 Dockge**。

---

## 8. 虚拟化（PVE）

| 功能 | 别人（厂商套件 / Unraid VM） | 我们 | 优先级 |
|---|---|---|---|
| 节点/VM/LXC 监控与电源等 | 深度不一 | ⬛ **已有完整 Proxmox 模块** | 保留，不阻塞家庭入口 |

OMV 跑在 PVE 上：盘 SMART 需**直通**才有意义——与「虚拟盘无 SMART」同类问题。

---

## 9. 账号 / 系统管理（刻意砍）

| 功能 | 别人 Web 很强 | 我们 |
|---|---|---|
| 用户/权限/ACL | ✅ | ❌ MyHomelab 不做 |
| 共享文件夹 CRUD | ✅ | ❌ |
| 网络 Bond/VLAN | ✅ | ❌ |
| 插件商店 | ✅ | ❌ |
| 更新系统/套件 | ✅ | ❌ |
| 独立 OMV 新 UI 项目 | — | 🟡 以后另开仓库做 |

---

## 10. 建议产品范围（可执行）

### A. 必做（对齐「有用的配套 App」+ 你们已定方向）

| # | 能力 | 对标 | Phase |
|---|---|---|---|
| 1 | 统一配置 + 测连接 + Keychain | 所有配套 App 的「添加 NAS」 | P0 |
| 2 | OpenList 文件浏览 / 搜索 / 直链 / SenPlayer | Drive / Qfile | P1 |
| 3 | Quark Auto Save 任务 | 自建特色（别人少有） | P1b |
| 4 | Immich 概览 + 跳转 | Photos 轻量版 | P2 |
| 5 | Jellyfin 继续看 / 最近加 + 跳转 | Video 轻量版 | P3 |
| 6 | 首页：Beszel 资源 + OMV 盘温健康 + 下载摘要 + Dockge 摘要 | DS finder + Unraid Dashboard | P4 |
| 7 | qBittorrent 不回归 | Download | 已有 |

### B. 值得做但可后置

| 能力 | 原因 |
|---|---|
| 盘详情折叠完整 SMART | 极客需要，首页不需要 |
| 温度历史（Scrutiny） | 体验好，多一个服务 |
| 磁盘高温本地通知 | 配套 App 差异化 |
| Dockge Stack 启停 | 协议成本高 |
| OpenList 简单上传 | 常用但可先外链 Web |
| 菜单栏/小组件盘温 | macOS/iOS 锦上添花 |

### C. 明确不做（别人有或只有 Web 有）

| 能力 | 原因 |
|---|---|
| SMB/NFS/WebDAV 配置 | 行业移动端也弱；文件走 OpenList |
| OMV/ZFS 破坏性操作 | 安全红线 |
| App 内完整播放器 | 用 SenPlayer / 官方 App |
| Immich 备份/刮削复刻 | 官方更强 |
| AI 盘预测、厂商云监控 | 无数据/无授权 |
| 再造一个 OMV 全功能 WebUI | 另开项目 |

---

## 11. 和「一个厂商全家桶」比，我们强在哪

| 维度 | 厂商 App | MyHomelab |
|---|---|---|
| 绑定硬件/系统 | 强绑定 | 服务可换 |
| 文件 | 自有协议 | OpenList 统一本地+网盘 |
| 照片/影视 | 封闭套件 | Immich + Jellyfin 开放 |
| 夸克转存 | 基本没有 | QAS 可集成 |
| 盘健康 | 完善 | OMV SMART 可做到「够用」 |
| 容器 | 参差 | Dockge 摘要 + 已有 Portainer 系 |
| PVE | 无/弱 | **已有深度模块**（稀缺） |

---

## 12. 一句话

**别人做的是「拆开的官方套件」；我们做的是「自建服务聚合壳」。**  

能做且该做的：监控（Beszel + 盘 SMART）+ 文件（OpenList）+ 照片/影视概览 + 下载 + 转存 + 容器摘要。  
不该做的：NAS 系统管理全套、共享协议配置、高危存储操作、复刻官方媒体客户端。
