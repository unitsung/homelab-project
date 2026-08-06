# Homelab

[English](README.md) · [中文](README.zh-CN.md)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-lightgrey.svg)](HomelabSwift/)
[![Upstream](https://img.shields.io/badge/upstream-JohnnWi%2Fhomelab--project-informational)](https://github.com/JohnnWi/homelab-project)

基于 [JohnnWi](https://github.com/JohnnWi) 的 [Homelab Dashboard](https://github.com/JohnnWi/homelab-project) 的个人 **iOS** fork。

<p align="center">
  <img src="media-docs/screenshots/home-overview.png" width="280" alt="首页概览" />
  &nbsp;
  <img src="media-docs/screenshots/arcane.png" width="280" alt="Arcane" />
</p>

<p align="center"><sub>首页概览 · Arcane（Docker）</sub></p>

---

## 上游

这是 **fork**，不是从零重写。

| | |
| --- | --- |
| **上游** | [JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project)（已归档） |
| **原项目** | Homelab Dashboard — 面向自建服务的原生移动客户端 |
| **本仓库** | [unitsung/homelab-project](https://github.com/unitsung/homelab-project) |

**感谢 JohnnWi，也感谢所有上游贡献者。** 多服务面板、多实例、备份、解锁、整体架构，以及长期打磨，都是你们做出来的。这个 fork 能存在，是因为上游已经足够扎实——我只是在上面叠自己 NAS 真正用得到的东西，并不是要盖过原作。

原版功能清单、集成列表、截图和历史文档，请直接看 [上游 README](https://github.com/JohnnWi/homelab-project)。这里故意不全文照搬，免得文档和代码各走各的。

---

## 为什么 fork

我不是想另起炉灶替代 Homelab Dashboard，只是想：

> 留住上游客户端，再补上**自己 Homelab / NAS 日常会用到的模块**，让手机端管起来更顺手。

我这边大致是：

- 主机：**[OpenMediaVault](https://www.openmediavault.org/)**
- Docker：**[Arcane](https://github.com/getarcaneapp/arcane)**
- 以及 **OpenList**、**CloudSaver** 等天天在用的工具
- 首页布局和操作习惯按自己的喜好调过

其余大部分仍是上游的能力。我主要维护 **iOS**（`HomelabSwift/`）。Android 目录还在，但这里不继续开发；需要 Android 的话可以看 [kinderdash](https://github.com/ChaosieKinder/kinderdash)。

你如果也用得上，尽管用。只要我自己还在用，就会接着维护；精力会优先放在让**自己用着爽**的那些路径上（OMV、Arcane、自加模块之类）。这不等于什么场景都会管到——对你也有帮助的话，再好不过。

应用内更新只认本 fork 的 bundle（`com.unitsung.myhomelab`），不会去顶上游用户的安装和更新。

---

## 编译（iOS）

```text
HomelabSwift/Homelab.xcodeproj
```

1. 用较新的 **Xcode** 打开（本仓库目标 **iOS 26+**）。
2. 配好开发者签名。
3. 在真机上跑。

SideStore、AltStore Classic 这类侧载方式随你。仓库里的 IPA / `apps.json` 主要是我自己装包用的。

CI 这边**只跑 iOS 编译**，Android 流水线已关掉。

---

## 许可与版权

与上游一致，采用 **[Apache License 2.0](LICENSE)**。

归属说明见 **[NOTICE](NOTICE)**（原 Homelab Dashboard 与本仓库的继续分发）。

实务上可以这么理解（非正式法律意见，以完整许可文本为准）：

1. 再分发时带上 Apache 2.0 的 `LICENSE`。
2. 保留版权与致谢（`NOTICE`，以及源码里原有的声明）。
3. 标明软件有过修改（本 fork 就是）。
4. 可以对自己的改动主张版权。
5. 别让人误以为得到了原作者背书。

**版权**

- 原 Homelab Dashboard：JohnnWi / finalyxre 与上游贡献者  
  https://github.com/JohnnWi/homelab-project  
- 本仓库改动：见 [提交历史](https://github.com/unitsung/homelab-project/commits/main) 与 `NOTICE`

按**现状**提供，不作任何保证。用得好用得坏，风险自担。
