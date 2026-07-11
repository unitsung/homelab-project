# 同类 NAS 配套 App 调研（磁盘健康 / 监控怎么做）

> 目的：对照主流 NAS 配套应用，校准 MyHomelab 的 OMV「只看硬盘」体验。  
> 日期：2026-07。

---

## 1. 大厂怎么拆 App（很关键）

商业 NAS **几乎从不**做一个「全能 App」塞满所有能力，而是按场景拆：

| 厂商 | 系统/运维类 | 文件类 | 媒体/其他 | 健康洞察 |
|---|---|---|---|---|
| **Synology** | DS finder | Drive / DS file | Photos, Video… | Active Insight |
| **QNAP** | QManager | Qfile 等 | 媒体套件 | DA Drive Analyzer（AI 预测） |
| **TrueNAS** | Web + 第三方 Pulse/NASDeck | 文件客户端另说 | — | Scrutiny（专用 SMART） |
| **Unraid** | Unraid Remote / U-Manager / Connect | 部分带简易文件 | Docker/VM | 盘温 + SMART 告警 |
| **OMV** | **无官方移动端** | 用系统文件客户端 / AList 类 | — | WebUI SMART |

**对 MyHomelab 的启示：**  
你们已经在走「聚合多服务」路线（OpenList / Immich / Jellyfin / qBittorrent），这更像 **Homelab 总控台**，而不是第二个 OMV WebUI。  
磁盘健康应是 **首页一小块 + 二级列表**，不要做成 DSM Storage Manager 的移动完整复刻。

---

## 2. 各产品「磁盘健康」具体怎么呈现

### 2.1 Synology（DS finder + DSM）

**DS finder（移动运维）：**

- Storage：卷 / 硬盘 / 状态一览  
- 系统资源、通知、温度信息  
- 修过「取不到盘温时显示错误值」类 bug → 说明 **温度是移动端硬指标**

**DSM 桌面 Storage Manager（深度在 Web，移动只摘摘要）：**

- 盘列表：位置、健康状态、**温度**、序列号、固件  
- Health Info → Overview：**通电小时、当前温度、重连次数、坏扇区**  
- 再进 SMART 页：属性表 + 可跑 short/long 测试  

**移动端套路：** 先看「绿/红 + 温度」；完整 SMART 属性表是第二层。  
**几乎不在首页强调转速 RPM**（有属性，但不作为主 KPI）。

### 2.2 QNAP（QManager + Disk Health）

- QManager：CPU / 内存 / 在线用户 / 系统事件（运维总览）  
- Disk Health：温度告警阈值、SMART 测试计划、厂商方案（IronWolf Health、DA Drive Analyzer）  
- 深度健康分析常 **上云 / 专用套件**，不是塞进基础运维 App 的每一屏  

**套路：** 温度阈值 + 健康状态；高级预测另开产品。

### 2.3 TrueNAS + 第三方

| 产品 | 做法 |
|---|---|
| **TrueNAS 本体** | 后台持续盯关键 SMART；新版本甚至把完整 SMART 调度 UI 弱化，推荐专用工具 |
| **Scrutiny**（业界标杆） | 专用硬盘健康 Dashboard：自动发现盘、**只突出关键 SMART**、温度历史、Backblaze 式阈值、告警 webhook |
| **TrueNAS Pulse** | 第三方 iOS：池健康、盘、**温度**、告警、任务 |
| **NASDeck** | 第三方：SMART 详情、温度、错误、池/快照等管理向 |

**Scrutiny 的产品哲学最值得抄：**

1. 不要默认甩 40 行 SMART 原始表  
2. 只标 **Critical metrics**（重分配扇区、Pending、温度等）  
3. 列表一眼看出哪几块有问题  
4. 历史温度曲线（可选增强，非 MVP）

### 2.4 Unraid 配套

| 产品 | 磁盘相关 |
|---|---|
| **Unraid Remote** | 阵列容量、**每盘温度**；Dashboard 甚至加 **max HDD/SSD temp** |
| **U-Manager** | Array：用量、温度、空闲、**disk health status** |
| **WebGUI** | SMART 属性变化 → 盘旁 **橙色图标**；点盘名看报告 |

**套路：** Dashboard 直接挂 **最高盘温** + 每盘温度；异常用颜色，不堆表格。

### 2.5 OMV

- **无官方移动配套**  
- 社区多年诉求都是：文件访问用第三方；管理靠浏览器  
- SMART 在 Web：设备网格 + 状态灯 + Information 多 Tab  

MyHomelab 做 OMV 盘监控，在生态上反而是 **补位**（别人没有原生 App）。

---

## 3. 跨产品共性（可当设计规范）

### 3.1 信息层级（几乎统一）

```text
L0 首页摘要
   「全部正常 · 最高 41°C · 4 盘」
   或异常：「1 盘警告 · sdb 48°C」

L1 磁盘列表（每行）
   型号/槽位 · 状态色点 · 温度 · （可选）容量/类型 HDD|SSD

L2 磁盘详情
   通电时间 · 温度 · 关键坏块指标 · 健康说明
   「查看全部 SMART」折叠或次级页

L3 可选增强
   温度历史曲线 · 跑 short test · 推送告警
```

### 3.2 主 KPI 排序（移动端）

| 优先级 | 指标 | 说明 |
|---|---|---|
| P0 | 健康状态（好/警告/差） | 所有产品都有色点 |
| P0 | 温度 | 移动端第一实时量 |
| P1 | 通电小时 / 容量 / 型号 | Overview 标准字段 |
| P1 | 重分配/Pending 扇区 | 坏盘预警，Scrutiny 重点 |
| P2 | 完整 SMART 表 | 给极客，默认折叠 |
| P2 | 转速 RPM | 桌面 SMART 里有；**移动端很少做主展示** |
| P3 | 历史曲线 / AI 预测 | Scrutiny / QNAP DA |

**对你「温度 + 转速」的建议：**

- **温度：必做**，与行业一致  
- **转速：可做**，但作为副信息（机械盘显示 `7200 RPM`，SSD 显示 `SSD` / `—`）  
- 不要把 RPM 做成和温度同等大的主数字（别人基本不这么做）

### 3.3 明确不做 / 很少做的事（移动配套）

| 能力 | 行业常见做法 |
|---|---|
| 在手机里配 SMB/NFS/WebDAV 共享 | **少见**；大厂拆到 Web 管理 |
| 手机里跑完整 SMART long test 当默认 | 有但次要；先看状态 |
| 手机里管理 RAID/ZFS 破坏性操作 | 有也是付费/专业第三方，且强确认 |
| 一个 App 既是文件又是运维又是相册 | 大厂拆 App；自建 Homelab 可聚合，但模块要分清 |

这直接支持你的决策：**MyHomelab 不做 SMB/NFS/WebDAV**。

---

## 4. 架构怎么取数（别人怎么分层）

```text
商业 NAS:
  厂商私有 API → 官方 App

TrueNAS / Unraid:
  官方 REST/API 或中间层 → 第三方 App

硬盘专项:
  smartctl/smartd → Scrutiny Collector → Web UI / 告警

OMV:
  WebUI = RPC → 无官方 App → 自建可直连 RPC 或旁路 Scrutiny
```

**两条可行路径（OMV on PVE）：**

| 路径 | 做法 | 优点 | 缺点 |
|---|---|---|---|
| **A. 直连 OMV Smart RPC** | `getList` + `getAttributes` | 不增组件 | 无历史曲线；PVE 需盘直通 |
| **B. 旁路 Scrutiny** | Docker 跑 Scrutiny，App 读其 API/页 | 历史温度、阈值成熟 | 多一个服务 |
| **C. Beszel + 磁盘插件/指标** | 系统指标用 Beszel | 你们已有 | 盘 SMART 未必完整 |

**推荐：** MyHomelab MVP 走 **A**；若以后想要温度历史，再 **B** 可选接入，不必一上来。

---

## 5. MyHomelab 可直接抄的 UI 规格

对标：**Unraid Remote 首页 max temp + Synology Overview 字段 + Scrutiny 关键指标**。

### 首页卡片

```text
磁盘健康
  ● 全部正常          最高温度 41°C
  4 块盘 · 点按查看
```

异常时：

```text
磁盘健康
  ● 1 警告            sdb 52°C
  点按处理
```

### 列表行

```text
[HDD] WDC WD80EFPX-...     ● 正常
      3.5" · 8 TB          38°C · 7200 RPM
```

```text
[SSD] Samsung 990...       ● 正常
      NVMe · 2 TB          42°C · —
```

### 详情（默认）

- 状态说明（绿/橙/红一句人话）  
- 温度、转速（若有）、通电时间  
- 重分配扇区 / Pending（>0 高亮）  
- 折叠：完整 SMART 属性  

### 明确不做（与行业一致）

- 共享协议管理  
- 默认展示 40 行原始 SMART  
- 未直通时假装有真实 SMART（显示「虚拟盘无 SMART」）

---

## 6. 和本项目现有能力的拼图

| 能力 | 对标谁 | 你们用什么 |
|---|---|---|
| CPU/内存/网速 | DS finder 资源页 / Unraid Remote | **Beszel**（已有） |
| 盘温/健康 | DS finder Storage / Unraid 盘列表 | **OMV Smart 只读** |
| 文件 | Drive / Qfile | **OpenList** |
| 照片 | Photos | **Immich** |
| 影视 | Video / Infuse 类 | **Jellyfin + SenPlayer** |
| 下载 | Download | **qBittorrent** |
| 容器 | 部分 Unraid App | **Dockge** |
| 夸克转存 | 无直接对标 | **Quark Auto Save** |

整体形态更接近：**「自建版 DS finder + Drive + Photos 的聚合壳」**，而不是单一 NAS 厂商全家桶。

---

## 7. 结论（给执行用）

1. **OMV 无官方配套 App**；做盘监控是差异化补位。  
2. 行业移动端主 KPI 是 **状态色 + 温度**；转速可有但次要。  
3. **首页摘要 → 列表 → 详情** 三层，抄 Synology Overview + Unraid max temp。  
4. **不要做** SMB/NFS/WebDAV；大厂也不把这事放在运维小 App 核心路径。  
5. 深度 SMART 历史可学 **Scrutiny**，但 MVP 直连 OMV RPC 即可。  
6. 完整管理 UI 仍适合 **独立 OMV 项目**；MyHomelab 只做「一眼健康」。

相关内部文档：

- [`myhomelab-roadmap.md`](./myhomelab-roadmap.md)  
- [`omv-management-project-plan.md`](./omv-management-project-plan.md)
