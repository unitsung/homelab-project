# 家庭存储拓扑与 App 职责（按实际布局）

> 用户环境：PVE → OMV 8 + ZFS。  
> **已确认：** 主文件 `tank/media`；备份相关两套存储 **tank** + **archive**；rsync 为 **OMV 计划任务**，把 tank 上的照片与备份拷到 `archive/backup`。

---

## 1. 已确认拓扑

```text
tank/                              ZFS pool（在线主池 / 热侧）
├── media/                         ★ 主文件 → OpenList → App「文件」
│   └── 影视 / 音乐 / 下载 …
├── …/照片或备份相关路径 …          ★ rsync 源之一（照片）
└── backup/（或等价备份数据集）     ★ rsync 源之一（备份落盘）
    └── …

archive/                           ZFS pool（冷备盘 / 冷侧）
└── backup/                        ★ rsync 目标：接收 tank 照片 + 备份
    └── …

Immich library                     ★ 独立照片库 → App「照片」（Immich API）
                                   不作为 OpenList 主浏览根

OMV Rsync（计划任务）
  tank 上的「照片 + 备份」  ──rsync──►  archive/backup
```

| 存储 | 角色 | App |
|---|---|---|
| **tank/media** | 日常影音/下载等 | 文件 Tab（OpenList） |
| **tank** 上照片/备份数据 | 热侧备份与照片副本来源 | 容量 + rsync **源**状态；可选只读浏览 |
| **archive/backup** | 冷备落点 | 容量 + rsync **目标**；默认不浏览 |
| **Immich** | 相册产品 | 照片 Tab |
| **ZFS 快照** | tank / archive 时间点 | 只读摘要 |

**数据流（备份安心感）：**

```text
手机/Immich / 其它
        │
        ▼
   tank（热）  ──OMV rsync 计划──►  archive/backup（冷）
   照片 + 备份                         拷贝落地
```

App 要回答的是：

1. 热盘 tank、冷盘 archive 是否健康（SMART + 容量）  
2. **rsync 最近有没有成功把照片/备份打到 archive**  
3. 关键 dataset 的 ZFS 快照是否还在按时产生  

---

## 2. 路径与入口对照

| 路径 | 人话 | App 入口 | 后端 |
|---|---|---|---|
| `tank/media` | 主文件 | **文件** | OpenList |
| Immich 库 | 家庭相册 | **照片** | Immich API |
| tank 照片/备份源 | 热侧备份数据 | 首页容量；可选只读 OpenList | 路径以你 OMV 共享/实际 dataset 为准 |
| `archive/backup` | 冷备 | 首页「冷备同步」目标 | 不默认进文件 Tab |
| OMV Rsync 计划 | 热→冷拷贝 | 首页同步卡 | 只读监控（见 §4） |
| ZFS 快照 | tank + archive | 首页快照摘要 | 只读 list |

**原则：**

- 找片/翻 media → OpenList。  
- 看相册 → Immich。  
- 冷备有没有跟上 → **OMV rsync 状态** + archive 容量/健康。  
- 误删回滚 → 只展示快照是否新鲜；**不在 App 回滚**。

---

## 3. App 与路径的边界（已锁定 · 全部服务）

| 谁 | 职责 |
|---|---|
| **你 / 各服务端** | 挂载、库路径、rsync 源目标、ZFS dataset、权限 |
| **MyHomelab App** | **只调 API**；OpenList / Immich / Jellyfin / OMV / … **返回什么就显示什么** |

文档里的 `tank/media`、`archive/backup` 等只是你环境的运维说明，**禁止写进 App 硬编码**。

---

## 4. rsync：OMV 计划任务（已确认）

### 业务含义

| 项 | 值 |
|---|---|
| 调度 | **OMV 自带 Rsync 计划任务**（非手写 cron 为主） |
| 方向 | **tank → archive** |
| 内容 | 主要是 **照片 + 备份**（不是整池 media 全量，除非你任务里另配了） |
| 目标 | **`archive/backup`** |

### App 展示（只读）

```text
冷备同步（OMV Rsync）
  ● 正常 / ⚠ 超过预期周期未成功 / ✕ 上次失败
  照片 → archive/backup    最近成功：昨天 03:12
  备份 → archive/backup    最近成功：昨天 03:40
  目标池：archive · 已用 xx%
```

多任务时按 OMV 任务名分行；源/目标显示为 `tank/… → archive/backup`。

### 数据怎么拿（已锁定：最简）

**采用 Healthchecks 心跳**（见 [`decisions.md`](./decisions.md)）：

1. OMV rsync 计划成功结束时 `curl` 一次 Healthchecks ping  
2. App 用已有 **Healthchecks** 客户端读 last ping / 是否超时  
3. 首页一张卡：最近成功时间 + 绿/黄/红  

**不做：** 解析 rsync 全量日志、状态 JSON Gateway、App 改 OMV 任务。  

**App 禁止：** 创建/修改/删除 OMV rsync 任务。

---

## 5. 双盘容量与 SMART

首页存储相关建议拆成：

```text
硬盘
  tank 池相关盘   SMART · 温度
  archive 冷备盘  SMART · 温度

容量
  tank/media      xx%
  tank（备份/照片源） yy%
  archive/backup  zz%   ← 冷备是否快满
```

冷备盘写满会导致 rsync 失败，**archive 容量**和 **rsync 成功时间**要一起看。

---

## 6. ZFS 快照白名单（建议）

| 数据集 | 为何盯 |
|---|---|
| `tank/media` | 主文件误删保护 |
| tank 上备份/照片相关 dataset | 热侧备份 |
| `archive/backup` | 冷备自身是否也有快照策略（若你有） |

展示：每数据集「最近快照时间 · 数量」；超过阈值未更新则警告。  
**禁止** App：`zfs destroy` / `rollback` / 创建快照。

---

## 7. Immich / media / 冷备关系图

```text
手机 ──► Immich 库 ──► App 照片
              │
              │ 另有备份副本落在 tank 备份/照片路径
              ▼
         tank（热）  ──OMV rsync 计划──►  archive/backup（冷）
              │
              └── tank/media ──OpenList──► App 文件 / Jellyfin
```

| 问题 | 去哪 |
|---|---|
| 最近照片好不好看 | Immich |
| 电影下载在哪 | OpenList → media |
| 冷备昨晚有没有跑完 | OMV rsync 状态卡 |
| archive 会不会满 | archive/backup 容量 |
| 能不能按时间点找回 | ZFS 快照摘要（操作在 OMV/CLI） |

---

## 8. 首页卡片（按本布局）

```text
┌──────────────────────────────────────┐
│ 系统（Beszel）                        │
├──────────────────────────────────────┤
│ 硬盘 SMART · tank 盘 + archive 盘    │
├──────────────────────────────────────┤
│ 容量 · media · tank备份侧 · archive  │
├──────────────────────────────────────┤
│ 冷备同步 · OMV rsync · 最近成功时间   │
│   照片 / 备份 → archive/backup        │
├──────────────────────────────────────┤
│ ZFS 快照 · tank/* · archive/backup   │
├──────────────────────────────────────┤
│ 下载 · 容器 · 夸克 …                  │
└──────────────────────────────────────┘
```

---

## 9. Phase

| 能力 | Phase |
|---|---|
| OpenList × `tank/media` | P1 |
| Immich | P2 |
| SMART（tank + archive 相关盘） | P4 |
| OMV rsync → archive 状态 | P4（Healthchecks 或状态文件） |
| ZFS 快照摘要 | P4b / Gateway |
| archive 只读浏览 | 默认不做 |

---

## 10. 已确认项 / 仍可细化

| 项 | 状态 |
|---|---|
| rsync = OMV 计划任务 | ✅ |
| 双盘：tank + archive，目标 `archive/backup` | ✅ |
| 内容：照片 + 备份 → archive | ✅ |
| rsync 监控 = Healthchecks 最简 | ✅ |
| OpenList：App 只调 API，挂载归服务端 | ✅ |
| 平台 iOS+macOS 统一，Android 不做 | ✅ |
| Healthchecks period / check id | 接入时配置，不进 Git |

Gateway 目标接口仍可为：

```text
GET /api/v1/storage/overview
→ disks[], pools/datasets[], rsyncJobs[], snapshots[]
```

---

## 11. 一句话

- **tank/media** → 日常文件（OpenList）  
- **Immich** → 相册  
- **tank 照片/备份 → OMV rsync → archive/backup** → 冷备是否跟上  
- **双盘 SMART + 容量 + 快照** → 热/冷是否都健康  

App 只读监控冷备链路，不改 OMV rsync、不动 ZFS 写操作。
