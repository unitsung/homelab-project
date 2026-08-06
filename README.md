# Homelab

[English](README.md) · [中文](README.zh-CN.md)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-lightgrey.svg)](HomelabSwift/)
[![Upstream](https://img.shields.io/badge/upstream-JohnnWi%2Fhomelab--project-informational)](https://github.com/JohnnWi/homelab-project)

An iOS-focused fork of [JohnnWi](https://github.com/JohnnWi)’s open-source [Homelab Dashboard](https://github.com/JohnnWi/homelab-project), shaped around my own Homelab.

<p align="center">
  <img src="media-docs/screenshots/home-overview.png" width="280" alt="Home overview" />
  &nbsp;
  <img src="media-docs/screenshots/arcane.png" width="280" alt="Arcane" />
</p>

<p align="center"><sub>Home overview · Arcane (Docker)</sub></p>

---

## Upstream

This is a **fork**, not a from-scratch rewrite.

| | |
| --- | --- |
| **Upstream** | [JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project) *(archived)* |
| **Original project** | Homelab Dashboard — a native mobile client for self-hosted services |
| **This repo** | [unitsung/homelab-project](https://github.com/unitsung/homelab-project) |

**Thanks to JohnnWi and everyone who contributed upstream.** You shipped the hard part: a solid multi-service dashboard, multi-instance support, backups, unlock, architecture, and a lot of polish over time. This fork only exists because that foundation is so good—I’m layering on what *I* need for my own NAS, not trying to outshine the original.

For the full original feature list, integrations, screenshots, and history, see the [upstream README](https://github.com/JohnnWi/homelab-project). I deliberately don’t mirror that catalog here; it would only go out of date.

---

## Why this fork

I wasn’t looking to replace Homelab Dashboard. I wanted something simpler:

> Keep the upstream app, then add the bits I actually use on **my** Homelab so phone-side management fits how I run things.

On my side that mostly means:

- Host: **[OpenMediaVault](https://www.openmediavault.org/)**
- Docker: **[Arcane](https://github.com/getarcaneapp/arcane)**
- Plus **OpenList**, **CloudSaver**, and other tools I live with every day
- Home layout and workflows tuned the way I like them

Almost everything else still comes from upstream. **iOS** (`HomelabSwift/`) is what I maintain. The Android tree is still in the repo for history, but I’m not developing it here—if you need Android, try [kinderdash](https://github.com/ChaosieKinder/kinderdash).

You’re welcome to use this fork if it helps. I’ll keep it alive while I’m using it myself, and I’ll care most about the paths that make **my** stack feel right (OMV, Arcane, the modules I added, and so on). That isn’t a promise to cover every setup or every request—if it works for you too, I’m glad.

In-app updates only apply to this fork’s bundle id (`com.unitsung.myhomelab`). They won’t hijack upstream installs.

---

## Build (iOS)

```text
HomelabSwift/Homelab.xcodeproj
```

1. Open the project in a recent **Xcode** (this tree targets **iOS 26+**).
2. Pick your development team for signing.
3. Run on a real device.

Sideloading with SideStore or AltStore Classic is fine if that’s your workflow. The IPA / `apps.json` bits in this repo are mainly how I install on my own phones.

CI here only runs **iOS compile checks**. Android CI is off.

---

## License & copyright

Same as upstream: **[Apache License 2.0](LICENSE)**.

Also see **[NOTICE](NOTICE)** for attribution of the original Homelab Dashboard and this continued work.

Practical summary (not legal advice—read the full license):

1. Keep the Apache 2.0 `LICENSE` when you redistribute.
2. Keep copyright and attribution (`NOTICE`, and headers where they exist).
3. Make clear that the software has been modified (this fork has).
4. You can claim copyright on *your* changes.
5. Don’t imply the original authors endorse your build.

**Copyright**

- Original Homelab Dashboard: JohnnWi / finalyxre and upstream contributors  
  https://github.com/JohnnWi/homelab-project  
- Changes in this repository: [commit history](https://github.com/unitsung/homelab-project/commits/main) and `NOTICE`

Provided **as is**, with no warranty. Use at your own risk.
