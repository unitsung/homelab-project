# Contributing to Homelab

Thanks for helping improve this project. This guide is for **external contributors** (pull requests). Owner workflow and agent automation details live in [`AGENTS.md`](AGENTS.md); when the two overlap, keep them consistent—update both if you change the rules.

## Branch model (GitHub Flow)

We do **not** use a long-lived `dev` / `develop` branch.

| Branch | Role |
|--------|------|
| `main` | Default branch. Target of all PRs. Tracks `origin/main`. |
| Short-lived topic branches | One feature, fix, or docs change per branch. Delete after merge. |

### Branch naming

Prefer:

- `feat/<short-name>` — new behavior or service support  
- `fix/<short-name>` — bug fixes  
- `docs/<topic>` — documentation only  
- `ci/<topic>` — GitHub Actions / automation  
- `chore/<topic>` — tooling, cleanup, non-user-facing maintenance  

Examples: `feat/qbittorrent-pause`, `fix/sonarr-empty-list`, `docs/contributing`.

### What to open a PR for

- Any change that should be reviewed before it lands on `main`
- Anything larger or riskier than a trivial typo
- Work that must not block an imminent release

Owner may commit small, low-risk changes directly on `main` per [`AGENTS.md`](AGENTS.md). Contributors should always use a branch + PR.

## How to contribute

1. Fork the repo (if you lack write access) and clone your fork.
2. Create a branch from the latest `main`:

   ```bash
   git fetch origin
   git checkout main
   git pull origin main
   git checkout -b feat/your-change
   ```

3. Make focused changes. Prefer small PRs over large multi-topic PRs.
4. Commit with a clear message (Conventional Commits style):

   - `feat: ...`
   - `fix: ...`
   - `docs: ...`
   - `ci: ...`
   - `chore: ...`

5. Push and open a PR against **`main`** on [unitsung/homelab-project](https://github.com/unitsung/homelab-project).
6. Describe **what** changed and **why**. Link related issues if any.
7. Ensure CI is green. Maintainers will review the diff and run platform checks as needed before merge.

## Local verification

Run checks based on what you touched—you do not need full Android + iOS builds for every PR.

| Change type | Expected check |
|-------------|----------------|
| Docs only (`README.md`, `CONTRIBUTING.md`, `AGENTS.md`, markdown, screenshots, license) | No app build required |
| Android-only code/resources | Android compile; unit tests if logic/networking/parsing/storage/ViewModels change |
| iOS-only code/resources | iOS compile; unit tests if logic/networking/parsing/storage/model behavior changes |
| Cross-platform service / shared release metadata / version bumps | Both Android and iOS compile |

### Android compile

```bash
cd HomelabAndroid
GRADLE_USER_HOME="$PWD/.gradle-home" \
JAVA_HOME=$(/usr/libexec/java_home -v 21) \
./gradlew :app:compileDebugKotlin --console=plain
```

### iOS compile (no simulator launch)

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

### Unit tests (when logic changes)

Android:

```bash
cd HomelabAndroid
GRADLE_USER_HOME="$PWD/.gradle-home" \
JAVA_HOME=$(/usr/libexec/java_home -v 21) \
./gradlew :app:testDebugUnitTest --console=plain
```

iOS (needs a simulator; adjust destination if needed):

```bash
cd HomelabSwift
xcodebuild test \
  -project Homelab.xcodeproj \
  -scheme Homelab \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/homelab-ios-test
```

List simulators with: `xcrun simctl list devices available`.

## Scope and hygiene

- Keep PRs focused; avoid drive-by refactors unrelated to the change.
- Do **not** commit generated release binaries (`.ipa`, `.apk`, `.aab`) unless maintainers explicitly ask.
- Do **not** manually edit `apps.json` or `app-version.json` for normal releases—the release workflow owns those.
- For release-bound version bumps, keep Android and iOS versions aligned (see [`AGENTS.md`](AGENTS.md)).
- Sideloading docs should say **AltStore Classic / SideStore** where relevant.

## Releases (maintainers)

Releases are tag-based (`vX.Y.Z`), not a permanent `dev` branch. Signed builds and AltStore source updates follow the process in [`AGENTS.md`](AGENTS.md) (Release Flow / Manifest Rules). Contributors normally do not need to run that pipeline.

## Questions

- Open an [issue](https://github.com/unitsung/homelab-project/issues) for bugs and feature discussion.
- For agent/automation conventions used by maintainers: [`AGENTS.md`](AGENTS.md).
