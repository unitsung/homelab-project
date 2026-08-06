# Homelab

This is a personal project, published only because GitHub forks cannot be made private.

Not a product, not a distribution, not seeking users. It is built for my own phones and shaped entirely around what I personally run.

No support. Please don't open issues or pull requests — I won't be triaging them. If something here is useful to you, fork it and make it yours; that's what I did.

It will break. It changes whenever I want it to, with no regard for compatibility, migrations, or anyone else's setup.

The Android tree (`HomelabAndroid/`) is inherited and unmaintained here. I don't ship or support it. If you want an actively developed Android client, see [ChaosieKinder/kinderdash](https://github.com/ChaosieKinder/kinderdash). Active work in this repo is **iOS only** (`HomelabSwift/`).

If you want the original app as its author intended it, go [upstream](https://github.com/JohnnWi/homelab-project) — including its full documentation and the list of supported integrations, which I haven't duplicated here because it would only drift.

## Why this fork exists

I run **[OpenMediaVault](https://www.openmediavault.org/)**, manage Docker primarily with **[Arcane](https://github.com/getarcaneapp/arcane)**, and use media/tools I actually care about (OpenList, CloudSaver, players oriented around my own habits, including China-facing ones). Language is **English + 中文** only — other locales were dropped on purpose; too much surface to maintain.

Most of the service dashboards still come from upstream. I only keep shaping the Swift app around my stack.

## Changes from upstream

Per Apache 2.0 §4(b), the notable modifications so far:

| Change | Why |
| --- | --- |
| iOS-first maintenance; Android left as-is | Personal bandwidth; I only use iPhone |
| English + 中文 only | Multi-locale matrix was more work than I want |
| Arcane / OpenList / CloudSaver / home overview / LAN–remote mode, etc. | What I run on OMV day to day |
| Keychain secrets use `AfterFirstUnlockThisDeviceOnly`, no iCloud Keychain sync | Keep tokens/passwords on-device, out of ordinary backup paths |
| In-app updates gated to bundle id `com.unitsung.myhomelab` | Upstream installs poll *their* feed; only this fork’s builds get *this* feed |
| Optional IPA / `apps.json` for my own sideload | Personal devices only; not an App Store product |

## Building

**iOS.** Open `HomelabSwift/Homelab.xcodeproj` in Xcode (not the repository root). Set your team, build for a device. Targets iOS 26+ in this tree.

Signing and refresh are your problem. I sometimes use AltStore Classic / SideStore for myself; there is no supported public distribution.

**Android.** Not maintained here. Prefer [kinderdash](https://github.com/ChaosieKinder/kinderdash), or open `HomelabAndroid/` at your own risk.

## Credits and license

All original work is by [JohnnWi](https://github.com/JohnnWi/homelab-project) and the contributors to homelab-project, licensed under the Apache License 2.0. This fork is distributed under the same license — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

Modifications in this repository are marked above and in the commit history.

Disclaimer: carried over from upstream and still true — provided as-is, with no guarantees, and no responsibility assumed for issues, data loss, or damages arising from its use.
