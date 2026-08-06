# Outcome

在 Homelab **iOS** 中新增 **OpenList 式** 的 **CloudSaver 服务模块**：用户添加 CloudSaver 实例后，可在 App 内通过 **逆向 CS API** 搜索网盘分享资源，并以 **海报墙（poster grid）** 为主结果形态展示（封面图来自 API 返回的 image/海报字段），再一键「想看」转存到自己的 **115 和/或 夸克** 预设目录；转存成功后通过可配置入口打开 **流媒体库**（Emby / Jellyfin 等）供 **SenPlayer 等外部播放器** 使用。

**主路径成功定义：** CloudSaver 回报转存成功（资源进入用户目标网盘目录）。  
**入库与可播：** 由用户家中可替换的 STRM/同步管道（当前如 QMediaSync 定时同步等）与媒体服务器完成；App **不**绑定 QMS/MoviePilot，**不**伪造 STRM/扫库进度。

# Scope

## P0（本 change 必须交付）

- **仅 HomelabSwift（iOS）**。
- 新 `ServiceType`（如 `cloudsaver`）、添加/登录实例（URL + 用户名/密码，token 刷新模式对齐 OpenList）、图标与文案、多实例、Keychain、自签名选项、备份键映射。
- `CloudSaverAPIClient`：基于已逆向/已验证的 CloudSaver HTTP 契约直连用户自建实例（**不依赖** MoviePilot；**不依赖** 半成品 `cloudsaver-proxy` 作为运行时；proxy 仅作接口参考）。
  - 登录与 token
  - 关键词搜索与结果解析（含 **海报/封面 URL（image）**、云盘类型、分享码、标题等）
  - 115 / 夸克：分享信息与转存到用户配置的目标目录（folder/CID）
- Dashboard：默认 **豆瓣榜单海报墙**（`GET /api/douban/hot`，chips 分类）；**资源搜索**（`/api/search`，对应网页 /resource）；海报墙 2 列 2:3 卡片；点榜单片名跳转搜索；「想看」、成功/失败反馈；加载更多。
- 海报图加载：使用搜索结果中的 image URL（经 CS 逆向 API 下发），异步加载、失败回退占位；**不**另接 TMDB 等第三方海报源作为 P0 依赖。
- **预设目录配置**（电影/剧集/动漫等分类目标；避免每次网页式选树）。未配置目录时明确报错。
- **转存成功后的后续体验（弱耦合）：**
  - 状态：`transferring` → `transferred` | `failed`（中性命名，不出现 `qms_*` 等品牌态）。
  - 文案：已保存到网盘，媒体库由用户侧同步工具在周期内更新（可配置说明文案/预计间隔，仅展示）。
  - 操作：可配置 `libraryOpenURL`，「打开媒体库」→ 系统/`openURL`（SenPlayer 或浏览器打开 Emby/JF 地址）。
  - 预留可选 `LibraryIngestNotifying`（或等价）钩子，**P0 默认 NoOp**，不调用 QMS。
- 必要 iOS 单元测试（模型解码、请求构造、ServiceType/backup 映射等）与 iOS 编译检查。

## P1（本 change 规格写明为后续增强，可不阻塞 P0 验收；实现可同 change 或 follow-up）

- 任务/历史列表、详情中可选覆盖目录、115/夸克优先级策略细化。
- 与 quark-auto-save 的关系：CS 直转夸克为主；追更场景可继续独立使用用户已部署的 quark-auto-save，App **不强制**对接。
- 设置项打磨：同步说明、默认盘策略。

## P2+（规格记录方向，非本 change 必须）

- 媒体库就绪探测（按标题查 Emby/JF）、深链到具体条目。
- 可选「立即同步」适配器（仅当工具提供正规 API 或用户接受逆向；失败不影响 `transferred`）。
- 磁链 → qBittorrent、115 离线下载作为旁路 adapter。
- Mikan / AutoBangumi 等追番只读或深链。
- Android。

# Non-goals

- **不做 Android**（本 change）。
- **不做 MoviePilot 集成**（过重，且偏服务端管理台，不符合 App 重点）。
- **不做** 自研重型 media-gateway / 生产环境 OpenCode Agent 编排层。
- **不做** 运行时依赖半成品 `cloudsaver-proxy`。
- **不做** 内置播放器；播放仅外部（SenPlayer 等）。
- **不做** Immich 模块。
- **不做** 绑定 QMediaSync / MediaWarp / 某一 STRM 品牌的编排或 token 续期。
- **不做** 完整网盘文件管理器、完整 Emby/JF 管理端。
- **不做** 种子站爬虫；qb 热门仅为后续可选旁路。
- 不把真实密码/token/CID 样例写入规格或证据。

# Acceptance examples

## 获取（P0）

- 用户在添加服务中看到 CloudSaver，填写实例 URL 与凭据后保存；连接校验失败时有可读错误。
- 搜索关键词后以 **海报墙** 展示结果：有 image 的条目显示封面；条目可区分 115 / 夸克等云盘类型（以 CS 返回为准）；点选可进入想看/详情。
- 已配置目标目录时，从海报墙点「想看」触发转存；成功显示成功反馈；失败显示后端/解析后的可读原因并可重试。
- 未配置对应盘目录时，不静默使用作者环境默认值，而是明确提示配置。
- 多实例与 Keychain 行为与其它服务（如 OpenList）一致。

## 转存后 → 入库 → 播放（P0 体验）

- 转存成功后，UI 进入「已转存 / 等待媒体库同步」类说明，**不**展示无法验证的 STRM/扫库步骤进度。
- 若配置了 `libraryOpenURL`，用户可一键打开媒体库（供 SenPlayer 等使用 Emby/JF 地址）。
- 未配置库 URL 时，主路径（转存）仍可用，仅隐藏或禁用打开库入口。
- 文档/文案声明：入库依赖用户自建同步（定时轮询等）；立即入库非 P0 保证。

## 后续（P1/P2 规格方向，验收可延后）

- P1：任务历史可回顾近期想看结果。
- P2：若实现就绪探测，须标明依赖的媒体服务器类型且失败时降级为「仅已转存」。

# Constraints and invariants

- 遵循 `AGENTS.md`：iOS-only 编译与相关单测；不强制 Android。
- 凭据仅 Keychain；日志与证据禁止明文密钥。
- 网络层复用 `BaseNetworkEngine` / 服务实例模式；客户端形态对齐 **OpenList**（APIClient + 专用 Views + ServiceLogin）。
- API 契约以用户部署的 CloudSaver 为准；以仓库外参考实现 `cloudsaver-proxy` 已验证端点为起点，兼容字段变更时优先保守解码。
- 可复制性：目录 CID、库 URL 均为用户配置；仓库与规格不含作者内网常量。
- 下游管道可替换：App 成功标准不依赖特定 STRM 工具品牌。
- Native artifact root：`docs`。

# Decisions

- **平台：仅 iOS。**
- **产品重点：Homelab App 内 CloudSaver 客户端（管理/搜/想看），非 MoviePilot、非重网关。**
- **对接：直连 CloudSaver（已逆向接口）；像 OpenList 一样作为 `ServiceType` 服务模块。**
- **结果 UI：P0 必须海报墙；封面数据来自 CS 逆向搜索 API 的 image 等字段，不另建海报服务。**
- **网盘：115 与夸克均可（CS 支持的转存目标）；预设分类目录，默认一键想看。**
- **不做 MP；不做生产 Agent 兼容层；不做 runtime 依赖 cloudsaver-proxy。**
- **播放：外部播放器；库入口为可配置 Emby/Jellyfin（或兼容）URL。**
- **入库：P0 不编排 QMS；承认定时同步延迟；状态机只到 transferred。**
- **后续档位已记录：** 提示文案 → 可选钩子/探测 → 可选立即同步适配器；换 STRM/JF 不推翻 App 主线。
- **quark-auto-save：** 用户可继续用于追更；点播主路径以 CS 直转为主，App 不强制集成。
- **Immich / 完整影视库管理模块：非本 change。**
- **种子/qb/115 离线/Mikan：后续旁路，非 P0。**

# Open questions

- （无阻塞项；已于用户确认后进入 Build。）

# Verification expectations

- iOS compile check（`AGENTS.md`）。
- 相关 iOS 单元测试（ServiceType、backup、客户端解码/请求构造；可用 mock）。
- 有实例时可手动：登录、搜索、想看、打开库；无实例时以契约/mock 证明客户端行为。
- 不要求 Android；不要求真实 QMS/Emby 集成测试作为 P0 通过条件。
