# AGENTS.md - Homelab

This repository is the single working copy for Homelab development.

## Repository Flow

- Work from `/Users/andreacip/Coding/homelab-project`.
- `origin` is the primary GitHub remote.
- `gitea` is an optional mirror remote only.
- Do not use `/Users/andreacip/Coding/Homelab` for new work.
- Keep `main` tracking `origin/main`.

## Development Rules

- Make focused commits with clear messages:
  - `feat: ...`
  - `fix: ...`
  - `docs: ...`
  - `ci: ...`
  - `chore: ...`
- Before committing app changes, verify at least the affected platform compiles.
- For release-bound changes, update both platform versions together:
  - Android: `HomelabAndroid/app/build.gradle.kts`
  - iOS: `HomelabSwift/Homelab/Info.plist`
- Keep Android `versionCode` and iOS `CFBundleVersion` aligned.
- Keep Android `versionName` and iOS `CFBundleShortVersionString` aligned.

## Build Checks

Android compile check:

```bash
cd /Users/andreacip/Coding/homelab-project/HomelabAndroid
GRADLE_USER_HOME=/Users/andreacip/Coding/homelab-project/HomelabAndroid/.gradle-home \
JAVA_HOME=$(/usr/libexec/java_home -v 21) \
./gradlew :app:compileDebugKotlin --console=plain
```

iOS compile check without launching simulators:

```bash
cd /Users/andreacip/Coding/homelab-project/HomelabSwift
xcodebuild build \
  -project Homelab.xcodeproj \
  -scheme Homelab \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/homelab-ios-dd \
  CODE_SIGNING_ALLOWED=NO
```

## Release Flow

- Release builds are manual unless signing automation is explicitly added later.
- The user provides the final signed `Homelab.ipa` and `Homelab.apk`.
- Create a GitHub release with tag `vX.Y.Z` and upload both assets.
- The `Update AltStore Source` workflow updates `apps.json` and `app-version.json`.
- After the workflow succeeds, pull `origin/main`.
- Push `main` to `gitea` only as a mirror if desired.

## Manifest Rules

- Do not manually edit `apps.json` or `app-version.json` for normal releases.
- The release workflow extracts iOS build metadata from the uploaded IPA.
- Always verify after a release:
  - `app-version.json.latest`
  - `apps.json` latest version entry
  - IPA/APK URLs point to the new release
  - GitHub Actions run status is `success`

## Platform Notes

- SideStore and AltStore Classic/World are supported through the IPA source.
- AltStore PAL in the EU requires Apple-notarized marketplace apps and a `marketplaceID`; the current IPA source is not a PAL marketplace source.
- Keep README wording specific: use "AltStore Classic / SideStore" when discussing sideloading.
