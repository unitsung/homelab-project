# Homelab · unitsung

自用 iOS Homelab 客户端。基于 [JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project) 继续改。

**感谢原作者 [JohnnWi](https://github.com/JohnnWi) 以及所有贡献者。** 上游把整套 Homelab 仪表盘从 0 做到可用——原生双端、多服务、多实例、备份与解锁等骨架都已经搭好。没有这份基础，就没有现在这个 fork。仓库仍按 [Apache License 2.0](LICENSE) 使用与致谢，详见 [NOTICE](NOTICE)。

## 我为什么 fork

不是要另起炉灶做一个「新产品」。

**初衷很简单：** 在上游已经做好的 Homelab 客户端上，加上**我自己本机 NAS 需要用的模块**，方便日常管理，把**我常开的那些应用**补进手机里。上游已经覆盖得很广；我只在自己真正会碰到的地方往上叠。

我的环境大致是：

| | |
| --- | --- |
| 主机 | [OpenMediaVault](https://www.openmediavault.org/) |
| Docker | [Arcane](https://github.com/getarcaneapp/arcane) 为主 |
| 手机端 | 只维护 **iOS**（`HomelabSwift/`） |
| 语言 | **English / 中文**（其它语言已去掉，懒得维护） |
| 其它 | OpenList、CloudSaver、以及我实际在用的播放/工具 |

服务面板与交互大多仍来自上游。完整集成列表、截图和「原版」说明请直接看 [upstream](https://github.com/JohnnWi/homelab-project)，这里不整份抄一遍，避免和代码脱节。

## 维护范围

- **会动：** Swift / iOS，围绕本机 OMV + 常用服务做小步补充与修缮。
- **不动：** `HomelabAndroid/` 仅保留，不做功能、不保证能编。需要 Android 可看 [kinderdash](https://github.com/ChaosieKinder/kinderdash)。
- **不接：** issue / PR 当工单用。有用就自己 fork 改。

代码放在 GitHub 上，主要是因为 fork 没法设成私有。**不是产品，不为公开分发拉用户。** 会按我自己的节奏改，不保证兼容别人的环境。

更新只认本仓库安装（bundle `com.unitsung.myhomelab`），不会去动上游用户的安装与更新通道。

## 编译

```text
HomelabSwift/Homelab.xcodeproj  →  Xcode，真机，iOS 26+
```

签名、过期刷新、是否用 SideStore / AltStore，都是自己的事。仓库里的 `apps.json` / release 是给我自己装包用的。

## 许可与免责

[Apache License 2.0](LICENSE) · [NOTICE](NOTICE)

原作者与贡献者归 JohnnWi 等上游。本仓库在相同许可下修改与分发；改动见 git history。

按现状提供，无任何保证。用坏了、丢数据、装不上，自行承担。
