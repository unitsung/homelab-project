# Homelab (personal fork)

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Personal iOS client for **my own** homelab. Not a product, not a distribution, not seeking users.

This repository is published mainly because GitHub forks cannot be made private. It is shaped around what I actually run day to day — not around supporting every setup on the internet.

<p align="center">
  <img src="media-docs/foto-ios/Dashboard.png" width="240" alt="Overview dashboard" />
</p>

---

## Disclaimer

**Read this before cloning, building, or installing anything.**

- Built **only for my own phones**, for personal convenience.
- Changes follow **my** stack, taste, and schedule. There is **no** compatibility promise, migration promise, or roadmap for anyone else.
- **No support.** Please do **not** open issues or pull requests expecting triage — I will not treat this as a community project.
- **No App Store.** Sideload / self-compile only. Builds may be free-Apple-ID signed and expire; refresh yourself.
- **It will break.** I change things whenever I want. Use at your own risk. No responsibility for data loss, broken installs, security incidents, or any damages.
- If something here is useful, **fork it and make it yours** — that is what I did with upstream.

This software is provided **as-is**, with **no warranties** of any kind.

---

## Why this fork exists

Upstream ([JohnnWi/homelab-project](https://github.com/JohnnWi/homelab-project), archived) is a solid dual-platform Homelab dashboard. I forked it to keep an **iOS** app that matches **my** machine:

| My setup | How this fork leans |
| --- | --- |
| Host OS | **[OpenMediaVault](https://www.openmediavault.org/)** |
| Docker UI | **[Arcane](https://github.com/getarcaneapp/arcane)** (primary container manager for me — not Portainer-first) |
| Media / files | **OpenList**, **CloudSaver**, players and external apps I actually use (incl. China-oriented habits) |
| Language | **English + 中文** only. Other locales were dropped on purpose — too much surface to maintain |
| Platform focus | **Swift / iOS only** for active work |

Most service dashboards, UI patterns, and integrations still come from **upstream**. I did not re-document the full “34 integrations” catalog here; it would only drift. For the original product intent and the wide service list, see upstream.

### What I tend to touch

- iOS / `HomelabSwift/` bugfixes and features I need
- Home overview, Arcane, OpenList / CloudSaver, qBittorrent details, LAN vs remote access, Chinese strings
- Occasional packaging (IPA source metadata) when I ship a build for myself

### What I do not maintain

- **Android** product work — tree may still exist under `HomelabAndroid/`, but I am **not** actively developing or supporting it
- Full multi-language coverage (IT / FR / ES / DE, etc.)
- Guarantees that your OMV / Docker / player stack will match mine

---

## Android

**I do not maintain Android here.**

If you want an actively developed Android Homelab-style client, look at other developers’ work, for example:

- [ChaosieKinder/kinderdash](https://github.com/ChaosieKinder/kinderdash)

Anything under `HomelabAndroid/` in this repo is **inherited / leftover**. Build it yourself if you must; **no guarantees**, no screenshots, no support.

---

## Language

In-app language is **English** and **中文** (Settings → Language).

I intentionally removed the rest of the translation matrix. Maintaining many locales is more work than I want for a personal app. If you need another language, fork and add it yourself — I am unlikely to expand the set.

---

## Screenshots (few)

Most UI is still upstream-looking. Only a couple of iOS shots so you know what “my” build roughly looks like:

| Overview | Example service |
| --- | --- |
| <img src="media-docs/foto-ios/Dashboard.png" width="180" /> | <img src="media-docs/foto-ios/Servarr.png" width="180" /> |

No Android gallery. For richer screenshots and the classic dual-platform pitch, see [upstream](https://github.com/JohnnWi/homelab-project).

---

## Security notes (iOS / Swift)

These matter because the app stores **API tokens, passwords, and session secrets** for your services.

| Topic | Behavior in this fork |
| --- | --- |
| **Where secrets live** | Service instances + app PIN are stored in the **iOS Keychain** (`KeychainService`), not UserDefaults / files. |
| **Keychain accessibility** | `AfterFirstUnlockThisDeviceOnly`, **not** iCloud Keychain sync. Secrets are intended to stay on **this device** and are excluded from ordinary backup / device-transfer paths that honor `ThisDeviceOnly`. Existing items are re-saved once on upgrade. |
| **UserDefaults** | Preferences only (theme, language, card order, update-banner dismiss state, etc.) — not credentials. |
| **Export backup** | Optional encrypted `.homelab` backup (password + AES-GCM). That is explicit export; protect the password. |
| **In-app update check** | Reads `HomelabUpdateManifestURL` / `HomelabUpdateDefaultURL` from **Info.plist**. Defaults to **this** repo (`unitsung/homelab-project`), **not** archived upstream `JohnnWi`. Set the manifest URL to an **empty string** to disable network update checks entirely. Toggle also exists in Settings when enabled. |
| **ATS** | Cleartext / arbitrary loads allowed for local homelab HTTP — expected for LAN services; still use HTTPS where you can. |

I do **not** claim formal security certification. This is “good enough for my phone on my LAN,” not a compliance product.

---

## Build (self-compile)

There is **no** supported binary distribution for the general public. If you use this code, **compile it yourself**.

### iOS (what I actually work on)

1. Open `HomelabSwift/Homelab.xcodeproj` in a recent Xcode (targets **iOS 26+** in this tree).
2. Set your own development team / signing.
3. Build for a real device.

Optional install path I use for my devices: **AltStore Classic / SideStore** with this repo’s source URL (when I publish an IPA for myself):

```
https://raw.githubusercontent.com/unitsung/homelab-project/main/apps.json
```

Signing, expiry, and refresh are **your** problem. Free Apple ID profiles expire; I do not provide commercial signing.

To silence update checks in a private build, clear `HomelabUpdateManifestURL` in `HomelabSwift/Homelab/Info.plist`.

### Android (not supported)

Open `HomelabAndroid/` in Android Studio, JDK 21, `./gradlew assembleDebug` — or better, use a maintained Android project such as [kinderdash](https://github.com/ChaosieKinder/kinderdash).

---

## Repository layout

| Path | Role |
| --- | --- |
| `HomelabSwift/` | **Active** — iOS app (SwiftUI) |
| `HomelabAndroid/` | Inherited / unmaintained here |
| `apps.json` / `app-version.json` | Optional sideload / in-app update metadata for **my** releases |
| `docs/` | Static pages (privacy / support leftovers) |
| `AGENTS.md` | Notes for automated agents working in this repo |

---

## Maintenance expectation

Personal bandwidth is limited.

- Fixes and features prioritize **Swift / iOS** and **my OMV + Arcane** workflow.
- Releases are irregular, when I need them.
- Documentation here stays short on purpose.
- Do not expect replies, roadmaps, or issue triage.

If you need the original app “as the author intended,” use [upstream](https://github.com/JohnnWi/homelab-project) (archived) and its full documentation.

---

## License & attribution

Licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

Original Homelab Dashboard work remains credited to **JohnnWi** and contributors. This fork’s modifications are visible in git history (personal iOS focus, Chinese + English only, Arcane / OpenList / CloudSaver oriented changes, packaging for my devices, etc.).

Fork, modify, and redistribute under Apache 2.0 if you want — keep license, notices, and note that the software has been modified.
