# Homelab

[English](README.md) · [中文](README.zh-CN.md)

这是优秀开源项目 [JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project) 的个人 fork，当前以 **iOS** 为主。

非常感谢原作者 **[JohnnWi](https://github.com/JohnnWi)** 以及所有贡献者。上游已经把原生 Homelab 仪表盘做得相当完整——多服务、多实例、备份与解锁等能力都已具备。本仓库是在这份成果上继续添加功能；没有上游，就没有后面的这些改动。

<p align="center">
  <img src="media-docs/screenshots/home-overview.png" width="280" alt="首页概览" />
  &nbsp;
  <img src="media-docs/screenshots/arcane.png" width="280" alt="Arcane" />
</p>

<p align="center"><sub>首页概览 · Arcane（Docker）</sub></p>

## 为什么 fork

并不是要从头再造一款 App。

**初衷很简单：** 保留上游已经做好的 Homelab 客户端，再补上**我自己本机 NAS / Homelab 日常会用到的模块**，把常用服务接到手机上，方便管理。

我这边大致是：[OpenMediaVault](https://www.openmediavault.org/) 主机、用 [Arcane](https://github.com/getarcaneapp/arcane) 管 Docker，以及 OpenList、CloudSaver 等我实际在用的工具；界面语言为 **English / 中文**（其它语言已去掉，减轻维护负担）。

服务面板和交互大多仍来自上游。完整集成列表、截图与原版文档请直接看 [upstream](https://github.com/JohnnWi/homelab-project)，这里不整份复制，避免和代码脱节。

## 维护范围

| 部分 | 说明 |
| --- | --- |
| **iOS**（`HomelabSwift/`） | 持续维护 |
| **Android**（`HomelabAndroid/`） | 仅保留，不在此积极开发。需要 Android 可参考 [kinderdash](https://github.com/ChaosieKinder/kinderdash) |

如果你也用得上，欢迎自取。我会**积极维护**，但重点仍是我自己每天在用的那部分——本机 NAS / Homelab、Arcane、我加的模块、中英界面等，先保证**自己用着爽**。不保证覆盖所有场景或每条需求；对你有帮助就更好了。

应用内更新只针对本 fork 的 bundle（`com.unitsung.myhomelab`），不会影响上游用户的安装与更新。

## 编译

用 Xcode 打开 `HomelabSwift/Homelab.xcodeproj`，配置签名后在真机运行（本仓库目标 **iOS 26+**）。

是否用 SideStore / AltStore Classic 等侧载方式由你自行决定。仓库中的 `apps.json` / release 资源主要是我自己装包用的。

## 许可

采用 [Apache License 2.0](LICENSE)，详见 [NOTICE](NOTICE)。

原 Homelab Dashboard 版权归 JohnnWi 与上游贡献者。本仓库在相同许可下分发，修改记录见 git history。

软件按现状提供，不附带任何保证，使用风险自负。
