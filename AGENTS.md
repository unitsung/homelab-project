# AGENTS.md - Homelab

This repository is the single working copy for Homelab development.

## Repository Flow

- Work from this repository root only.
- `origin` is the primary GitHub remote.
- `gitea` is an optional mirror remote only.
- Do not use the old Gitea working copy for new work.
- Keep `main` tracking `origin/main`.

## Branch Strategy

External contributors: see [`CONTRIBUTING.md`](CONTRIBUTING.md) (GitHub Flow: PR to `main`, no long-lived `dev`).

- Use `main` for normal owner-directed changes, release preparation, and release follow-up commits.
- Create a short-lived branch for larger/riskier work, external PR review, or changes that should not block release work.
- Prefer branch names like `feat/service-name`, `fix/issue-name`, `docs/topic`, or `ci/topic`.
- Use a separate git worktree only when another uncommitted task is already in progress and switching branches would risk mixing changes.
- Do not merge or close external PRs without reviewing the diff and running the relevant checks.
- Do not introduce a long-lived `dev` / `develop` branch; keep GitHub Flow (`main` + short-lived topic branches + release tags).

## Development Rules

- Make focused commits with clear messages:
  - `feat: ...`
  - `fix: ...`
  - `docs: ...`
  - `ci: ...`
  - `chore: ...`
- For release-bound changes, update both platform versions together:
  - Android: `HomelabAndroid/app/build.gradle.kts`
  - iOS: `HomelabSwift/Homelab/Info.plist`
- Keep Android `versionCode` and iOS `CFBundleVersion` aligned.
- Keep Android `versionName` and iOS `CFBundleShortVersionString` aligned.
- Do not commit generated release binaries (`.ipa`, `.apk`, `.aab`) unless explicitly requested.

## Verification Policy

- Run local checks based on the files touched; do not run every build for every change by default.
- Docs-only changes (`README.md`, `AGENTS.md`, license, markdown, screenshots) do not require local Android or iOS builds.
- Android-only code/resources require the Android compile check; run Android unit tests when logic, networking, parsing, storage, or ViewModels change.
- iOS-only code/resources require the iOS compile check; run iOS unit tests when logic, networking, parsing, storage, or model behavior changes.
- Cross-platform service changes, shared release metadata, or version bumps require both Android and iOS compile checks.
- Release publishing with user-provided signed `Homelab.ipa` and `Homelab.apk` does not require rebuilding locally unless source code changed in the same task.
- After pushing to `main`, always inspect the GitHub Actions `CI` run. The task is not complete if CI fails.

## Build Checks

Android compile check:

```bash
cd HomelabAndroid
GRADLE_USER_HOME="$PWD/.gradle-home" \
JAVA_HOME=$(/usr/libexec/java_home -v 21) \
./gradlew :app:compileDebugKotlin --console=plain
```

iOS compile check without launching simulators:

```bash
cd HomelabSwift
xcodebuild build \
  -project Homelab.xcodeproj \
  -scheme Homelab \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/homelab-ios-dd \
  CODE_SIGNING_ALLOWED=NO
```

## Test Checks

Android unit tests:

```bash
cd HomelabAndroid
GRADLE_USER_HOME="$PWD/.gradle-home" \
JAVA_HOME=$(/usr/libexec/java_home -v 21) \
./gradlew :app:testDebugUnitTest --console=plain
```

iOS unit tests require an available iOS simulator:

```bash
cd HomelabSwift
xcodebuild test \
  -project Homelab.xcodeproj \
  -scheme Homelab \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/homelab-ios-test
```

If the exact simulator is unavailable, list devices with `xcrun simctl list devices available` and adjust the destination.

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
- Keep README wording specific: use "AltStore Classic / SideStore" when discussing sideloading.

<comet-ambient-resume>
<!-- Managed by Comet. Edits inside this block may be replaced by comet init/update. -->
<!-- Contract: comet.resume_probe.v2 -->

## Comet Ambient Resume

在这个仓库中，开始处理需要改动或调查的任务前，如果可能存在活跃 Comet workflow，把当前用户请求传入只读探针：`comet resume-probe . --stdin --json`。

- 如果用户通过宿主明确调用任意 Comet Skill（例如 `@comet`、`/comet`、`@comet-native` 或 `/comet-hotfix`），显式调用优先于本恢复协议；不要运行 resume probe，直接进入被调用的 Skill。
- 只信任返回的 `workflow`、`skill` 和 `entrySource`；它们只由项目配置或无配置兼容回退决定。不得扫描或切换另一套 workflow。
- 如果 probe 返回 `auto_resume`，简短说明选中的 active change，并进入 `nextCommand` 指向的永久入口。不要把状态命令当作恢复入口直接推进。
- 如果 probe 返回 `ask_user`，只问一个简短问题并等待用户回复。
- 如果当前请求未明确调用 Comet Skill，且 probe 返回 `out_of_scope` 或 `none`，不要进入 Comet workflow。
- 如果配置或状态无效且没有 `nextCommand`，停止并报告原因；不要猜测另一个 workflow。
- 不能只因为存在 active change 就把无关任务挂到该 change。Native 的未提交改动由 Native 入口检查，不由探针自动归因。
</comet-ambient-resume>
