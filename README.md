# Homelab

[English](README.md) · [中文](README.zh-CN.md)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-lightgrey.svg)](HomelabSwift/)
[![Upstream](https://img.shields.io/badge/upstream-JohnnWi%2Fhomelab--project-informational)](https://github.com/JohnnWi/homelab-project)

A personal **iOS** fork of [**Homelab Dashboard**](https://github.com/JohnnWi/homelab-project) by [JohnnWi](https://github.com/JohnnWi).

<p align="center">
  <img src="media-docs/screenshots/home-overview.png" width="280" alt="Home overview" />
  &nbsp;
  <img src="media-docs/screenshots/arcane.png" width="280" alt="Arcane" />
</p>

<p align="center"><sub>Home overview · Arcane (Docker)</sub></p>

---

## Credits & relationship to upstream

This project is a **fork**, not a clean-room rewrite.

| | |
| --- | --- |
| **Upstream** | [JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project) (archived) |
| **Original product** | Homelab Dashboard — native mobile client for self-hosted services |
| **This repository** | [unitsung/homelab-project](https://github.com/unitsung/homelab-project) |

**Thank you to JohnnWi and all upstream contributors.** You built the foundation: multi-service dashboards, multi-instance support, backups, biometric unlock, the overall app architecture, and years of polish. This fork exists *because* that work is excellent—I’m only adding the pieces that fit **my** NAS and daily workflow on top of it.

For the full original feature set, integration list (~34 services), screenshots, and historical docs, please read the [upstream README](https://github.com/JohnnWi/homelab-project). I don’t copy that catalog here so it won’t silently go stale.

---

## Why this fork

I didn’t set out to replace Homelab Dashboard. The goal is straightforward:

> Keep the upstream client, then **add modules I use on my own Homelab / NAS**, so managing the stack from my phone is more pleasant.

In my setup that includes things like:

- **[OpenMediaVault](https://www.openmediavault.org/)** as the host
- **[Arcane](https://github.com/getarcaneapp/arcane)** as the main Docker UI
- **OpenList**, **CloudSaver**, and other tools I actually run

Most dashboards and patterns still come from upstream. Active product work here is **iOS** (`HomelabSwift/`). The Android tree is kept for history; it is **not** developed in this fork—see [kinderdash](https://github.com/ChaosieKinder/kinderdash) if you need Android.

If you use this fork too, you’re welcome. I’ll keep maintaining it while I rely on it myself, with priority on the paths that make **my** Homelab feel good day to day. That may not cover every request or every environment—if it helps you as well, even better.

In-app updates only target this fork’s bundle id (`com.unitsung.myhomelab`) and won’t push releases into upstream installs.

---

## Building (iOS)

```text
HomelabSwift/Homelab.xcodeproj
```

1. Open the project in a recent **Xcode** (this tree targets **iOS 26+**).
2. Set your development team under signing.
3. Build and run on a real device.

Sideloading (SideStore / AltStore Classic, etc.) is optional. Release IPA metadata in this repo is mainly for my own devices.

CI on this repository runs **iOS compile checks only** (Android CI has been disabled).

---

## License & copyright

This fork is distributed under the **[Apache License 2.0](LICENSE)**—the same license as upstream.

Please also read **[NOTICE](NOTICE)**, which records attribution for the original Homelab Dashboard and this continued distribution.

In short (not legal advice; see the full license text):

1. Keep the Apache 2.0 `LICENSE` when you redistribute.
2. Keep copyright / attribution notices (`NOTICE` and source headers where present).
3. State that the software includes modifications (this fork does).
4. You may add your own copyright for your own changes.
5. Do not imply endorsement by the original authors.

**Copyright**

- Original Homelab Dashboard: JohnnWi / finalyxre and upstream contributors  
  Upstream: https://github.com/JohnnWi/homelab-project  
- Modifications in this repository: see [git history](https://github.com/unitsung/homelab-project/commits/main) and `NOTICE`

Software is provided **as is**, without warranties of any kind. Use at your own risk.
