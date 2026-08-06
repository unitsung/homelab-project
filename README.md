# Homelab · unitsung

自用 iOS Homelab 客户端。从 [JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project) fork，按我自己的环境继续改。

**不是产品。** 不为公开分发、不为拉用户。代码放在 GitHub 上，主要是因为 fork 没法设成私有仓库。

## 我的环境

| | |
| --- | --- |
| 主机 | [OpenMediaVault](https://www.openmediavault.org/) |
| Docker | [Arcane](https://github.com/getarcaneapp/arcane) 为主 |
| 手机端 | 只维护 **iOS**（`HomelabSwift/`） |
| 语言 | **English / 中文**（其它语言已去掉，懒得维护） |
| 其它 | OpenList、CloudSaver、以及我实际在用的播放/工具习惯 |

服务面板大多仍是上游的能力。完整集成列表、截图和「官方」说明请看 [upstream](https://github.com/JohnnWi/homelab-project)，这里不重复抄一份，避免和代码脱节。

## 维护范围

- **会动：** Swift / iOS，围绕我自己的 OMV + Arcane 日常。
- **不动：** `HomelabAndroid/` 仅保留，不做功能、不保证能编。需要 Android 可看 [kinderdash](https://github.com/ChaosieKinder/kinderdash)。
- **不接：** issue / PR 工单。有用就自己 fork 改。

改动记录看 git history 即可。相对上游的大方向：个人栈优先、中英双语、Keychain 本机凭据、更新只认本仓库 bundle（`com.unitsung.myhomelab`），不会去顶上游用户的安装。

## 编译

```text
HomelabSwift/Homelab.xcodeproj   →  Xcode，真机，iOS 26+
```

签名、过期刷新、是否用 SideStore / AltStore，都是自己的事。仓库里的 `apps.json` / release 是给我自己装包用的，不是面向公众的商店。

## 许可

[Apache License 2.0](LICENSE) · 见 [NOTICE](NOTICE)

原作者与贡献者归 JohnnWi 等上游。本仓库在相同许可下修改与分发。

**免责：** 按现状提供，无任何保证。用坏了、丢数据、装不上、安全出事，自行承担。
