# Homelab

[English](README.md) · [中文](README.zh-CN.md)

A personal fork of the excellent [JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project) Homelab client, focused on **iOS**.

Huge thanks to **[JohnnWi](https://github.com/JohnnWi)** and every contributor. Upstream already ships a solid native Homelab dashboard—multi-service support, multi-instance setup, backups, unlock, and more. This fork stands on that work; without it, none of the extras below would exist.

## Why this fork

I didn’t set out to rebuild the app from scratch. The goal is simple: **keep the upstream foundation**, then add modules and services I use every day on **my own NAS / Homelab**, so day-to-day management is easier on my phone.

In practice that means things like my **[OpenMediaVault](https://www.openmediavault.org/)** host, **[Arcane](https://github.com/getarcaneapp/arcane)** for Docker, **OpenList**, **CloudSaver**, and other tools I actually run—plus **English and 中文** UI (other locales were dropped to keep maintenance light).

Most service dashboards and UI patterns still come from upstream. For the full original integration list, screenshots, and docs, please see [upstream](https://github.com/JohnnWi/homelab-project)—I don’t duplicate that catalog here so it doesn’t drift.

## What’s maintained

| Area | Status |
| --- | --- |
| **iOS** (`HomelabSwift/`) | Active |
| **Android** (`HomelabAndroid/`) | Inherited; not actively developed here. For Android, see [kinderdash](https://github.com/ChaosieKinder/kinderdash) |

If you find this fork useful, you’re welcome to use it. I’ll keep maintaining it as long as I use it myself—especially the pieces that make **my** Homelab feel good day to day (OMV, Arcane, the modules I added, Chinese/English UI, and so on). That doesn’t mean every request or every edge case will land; priority stays on the paths I actually run. If something helps you too, great.

In-app updates are scoped to this fork’s bundle id (`com.unitsung.myhomelab`), so they don’t interfere with upstream installs.

## Building

Open `HomelabSwift/Homelab.xcodeproj` in Xcode, set your signing team, and run on a real device (this tree targets **iOS 26+**).

Sideloading (e.g. SideStore / AltStore Classic) is optional and left to you. Repository `apps.json` / release assets are mainly for my own installs.

## License

Licensed under the [Apache License 2.0](LICENSE). See [NOTICE](NOTICE).

Original Homelab Dashboard copyright remains with JohnnWi and upstream contributors. This repository redistributes under the same license with modifications recorded in git history.

Provided as-is, without warranty of any kind. Use at your own risk.
