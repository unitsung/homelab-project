# iOS Home Dashboard Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the iOS home screen into a Homelab-titled, PVE-style metrics dashboard with Beszel-first cards, drag-reorderable monitor widgets, disk-temperature (not generic temps), Arcane username login fix, and per-service URL placeholders — iOS only.

**Architecture:** In-place enhancement of existing `HomeView` + `Views/Dashboard/*` + `DashboardSystemStore`. Add pure helpers (`DashboardCardID` order normalize, disk sensor filter) for unit tests. Persist card order in `SettingsStore`. Fix `ServiceLoginView` Arcane fields and `ServiceType.urlPlaceholder`. Update main OpenSpec `home-dashboard-overview` semantics away from「服务总览」.

**Tech Stack:** SwiftUI, Swift Charts (existing cards), `@Observable` stores, UserDefaults via `SettingsStore`, XCTest in `HomelabTests`, Xcode 26 / iOS 26 deployment.

**Design Doc:** `docs/superpowers/specs/2026-07-15-ios-home-dashboard-polish-design.md`

## Global Constraints

- Platform: **iOS only** — do not change Android
- Language for user-facing copy: zh-CN + en via existing `Translations*`
- Data source for system metrics: **Beszel primary**
- **No OMV / TrueNAS** integration this change
- **No PVE metrics** on home — service entry only
- **No ZFS card**; no full SMART report
- **No fabricated** CPU/memory/disk/container numbers without a real data source
- Drag-reorder: **monitor cards only** (not service launcher, not system health)
- Title: **Homelab**; Tab: **首页 / Home**
- Do not raise `IPHONEOS_DEPLOYMENT_TARGET` beyond project.yml
- Worktree may already have WIP diffs on Home/ServiceLogin/Dashboard — **integrate, do not blindly revert** unrelated WIP; only commit intentional polish changes
- Compile check (AGENTS.md):

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

---

## File map

| File | Responsibility |
|------|----------------|
| `HomelabSwift/Homelab/Models/DashboardCardID.swift` | Card IDs + `normalizeOrder` pure function |
| `HomelabSwift/Homelab/Utilities/DiskTemperatureSensorFilter.swift` | Pure filter for disk-like sensor names |
| `HomelabSwift/Homelab/Stores/SettingsStore.swift` | Persist `dashboardCardOrder` |
| `HomelabSwift/Homelab/Views/Dashboard/DiskTemperatureCard.swift` | Replace generic temperature UI |
| `HomelabSwift/Homelab/Views/Dashboard/TemperatureCard.swift` | Remove from home (delete file if unused) |
| `HomelabSwift/Homelab/Views/Home/HomeView.swift` | Section layout + reorderable grid |
| `HomelabSwift/Homelab/Views/ServiceLogin/ServiceLoginView.swift` | Arcane username + URL placeholder |
| `HomelabSwift/Homelab/Models/ServiceType.swift` | `urlPlaceholder` |
| `HomelabSwift/Homelab/Localization/Translations.swift` | New string keys if needed |
| `HomelabSwift/Homelab/Localization/Translations+Chinese.swift` | `launcherTitle`, `tabHome`, card titles |
| `HomelabSwift/Homelab/Localization/Translations+English.swift` | Same EN |
| `openspec/specs/home-dashboard-overview/spec.md` | Semantics update |
| `HomelabSwift/HomelabTests/DashboardCardOrderTests.swift` | Order normalize tests |
| `HomelabSwift/HomelabTests/DiskTemperatureSensorFilterTests.swift` | Sensor filter tests |

If XcodeGen is used for new files: run `xcodegen generate` in `HomelabSwift` after adding sources under `Homelab/` and `HomelabTests/` (both are folder-synced via `project.yml`). If the project is maintained only via `pbxproj`, add new Swift files to the Homelab / HomelabTests targets the same way recent Dashboard files were added.

---

### Task 1: Pure helpers + unit tests (card order + sensor filter)

**Files:**
- Create: `HomelabSwift/Homelab/Models/DashboardCardID.swift`
- Create: `HomelabSwift/Homelab/Utilities/DiskTemperatureSensorFilter.swift`
- Create: `HomelabSwift/HomelabTests/DashboardCardOrderTests.swift`
- Create: `HomelabSwift/HomelabTests/DiskTemperatureSensorFilterTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum DashboardCardID: String, CaseIterable, Codable, Identifiable, Hashable` with cases `cpu`, `memory`, `disk`, `diskTemperature`, `docker`
  - `static func normalizeOrder(_ raw: [DashboardCardID]) -> [DashboardCardID]`
  - `enum DiskTemperatureSensorFilter` with `static func diskSensors(from sensors: [String: Double]) -> [(name: String, celsius: Double)]`

- [ ] **Step 1: Write failing tests for order normalize**

Create `HomelabSwift/HomelabTests/DashboardCardOrderTests.swift`:

```swift
import XCTest
@testable import Homelab

final class DashboardCardOrderTests: XCTestCase {
    func testDefaultOrderWhenEmpty() {
        let result = DashboardCardID.normalizeOrder([])
        XCTAssertEqual(result, DashboardCardID.allCases)
    }

    func testPreservesKnownOrderAndAppendsMissing() {
        let result = DashboardCardID.normalizeOrder([.docker, .cpu])
        XCTAssertEqual(result.first, .docker)
        XCTAssertEqual(result[1], .cpu)
        XCTAssertTrue(result.contains(.memory))
        XCTAssertTrue(result.contains(.disk))
        XCTAssertTrue(result.contains(.diskTemperature))
        XCTAssertEqual(result.count, DashboardCardID.allCases.count)
    }

    func testDedupesDuplicates() {
        let result = DashboardCardID.normalizeOrder([.cpu, .cpu, .memory])
        XCTAssertEqual(result.filter { $0 == .cpu }.count, 1)
        XCTAssertEqual(result.count, DashboardCardID.allCases.count)
    }
}
```

- [ ] **Step 2: Write failing tests for disk sensor filter**

Create `HomelabSwift/HomelabTests/DiskTemperatureSensorFilterTests.swift`:

```swift
import XCTest
@testable import Homelab

final class DiskTemperatureSensorFilterTests: XCTestCase {
    func testKeepsDiskLikeNames() {
        let input: [String: Double] = [
            "nvme0n1": 42,
            "SSD": 38,
            "cpu_package": 70,
            "Core 0": 65,
            "hdd_bay1": 33
        ]
        let names = DiskTemperatureSensorFilter.diskSensors(from: input).map(\.name)
        XCTAssertTrue(names.contains("nvme0n1"))
        XCTAssertTrue(names.contains("SSD"))
        XCTAssertTrue(names.contains("hdd_bay1"))
        XCTAssertFalse(names.contains("cpu_package"))
        XCTAssertFalse(names.contains("Core 0"))
    }

    func testDropsNonPositiveTemps() {
        let input: [String: Double] = ["ssd0": 0, "nvme1": -1, "disk1": 40]
        let result = DiskTemperatureSensorFilter.diskSensors(from: input)
        XCTAssertEqual(result.map(\.name), ["disk1"])
    }

    func testSortsHottestFirst() {
        let input: [String: Double] = ["ssd_a": 30, "ssd_b": 50]
        let result = DiskTemperatureSensorFilter.diskSensors(from: input)
        XCTAssertEqual(result.map(\.celsius), [50, 30])
    }
}
```

- [ ] **Step 3: Run tests — expect compile/fail missing types**

```bash
cd HomelabSwift
xcodebuild test \
  -project Homelab.xcodeproj \
  -scheme Homelab \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/homelab-ios-test \
  -only-testing:HomelabTests/DashboardCardOrderTests \
  -only-testing:HomelabTests/DiskTemperatureSensorFilterTests
```

If simulator name differs: `xcrun simctl list devices available` and adjust.  
Expected: FAIL (types missing or tests not compiled).

- [ ] **Step 4: Implement helpers**

`HomelabSwift/Homelab/Models/DashboardCardID.swift`:

```swift
import Foundation

enum DashboardCardID: String, CaseIterable, Codable, Identifiable, Hashable {
    case cpu
    case memory
    case disk
    case diskTemperature
    case docker

    var id: String { rawValue }

    /// Default display order for the home metric grid.
    static var defaultOrder: [DashboardCardID] { Array(allCases) }

    /// Keeps first occurrence of each known id, then appends any missing cases in `defaultOrder`.
    static func normalizeOrder(_ raw: [DashboardCardID]) -> [DashboardCardID] {
        var seen = Set<DashboardCardID>()
        var result: [DashboardCardID] = []
        for id in raw where seen.insert(id).inserted {
            result.append(id)
        }
        for id in defaultOrder where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    static func normalizeOrder(rawValues: [String]) -> [DashboardCardID] {
        normalizeOrder(rawValues.compactMap(DashboardCardID.init(rawValue:)))
    }
}
```

`HomelabSwift/Homelab/Utilities/DiskTemperatureSensorFilter.swift`:

```swift
import Foundation

enum DiskTemperatureSensorFilter {
    private static let positiveKeywords = [
        "disk", "hdd", "ssd", "nvme", "drive", "wd", "seagate", "smart"
    ]
    private static let negativeKeywords = [
        "cpu", "core", "gpu", "package", "pch", "acpi", "soc"
    ]

    static func diskSensors(from sensors: [String: Double]) -> [(name: String, celsius: Double)] {
        sensors.compactMap { name, celsius -> (name: String, celsius: Double)? in
            guard celsius > 0 else { return nil }
            let lower = name.lowercased()
            let hitsPositive = positiveKeywords.contains { lower.contains($0) }
            let hitsNegative = negativeKeywords.contains { lower.contains($0) }
            // nvme/ssd names often lack "disk"; allow positive without requiring it
            guard hitsPositive, !hitsNegative else { return nil }
            return (name, celsius)
        }
        .sorted { $0.celsius > $1.celsius }
    }
}
```

Note: names like `nvme0n1` contain `nvme` → kept. `cpu_package` hits negative → dropped. If a name is only `temp1` it is dropped (not disk-like) — acceptable per design.

- [ ] **Step 5: Re-run unit tests — expect PASS**

Same `xcodebuild test` command as Step 3.  
Expected: **TEST SUCCEEDED** for those two classes.

- [ ] **Step 6: Commit**

```bash
git add HomelabSwift/Homelab/Models/DashboardCardID.swift \
  HomelabSwift/Homelab/Utilities/DiskTemperatureSensorFilter.swift \
  HomelabSwift/HomelabTests/DashboardCardOrderTests.swift \
  HomelabSwift/HomelabTests/DiskTemperatureSensorFilterTests.swift \
  HomelabSwift/Homelab.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: add dashboard card order and disk temp filter helpers

Pure functions for home metric reorder persistence and Beszel
disk-sensor filtering, with unit tests.
EOF
)"
```

Only add `project.pbxproj` if it actually changed after registering files.

---

### Task 2: Persist `dashboardCardOrder` in SettingsStore

**Files:**
- Modify: `HomelabSwift/Homelab/Stores/SettingsStore.swift`

**Interfaces:**
- Consumes: `DashboardCardID.normalizeOrder`
- Produces:
  - `var dashboardCardOrder: [DashboardCardID]` (private set + didSet persist)
  - `func setDashboardCardOrder(_ order: [DashboardCardID])`
  - `func moveDashboardCard(from source: IndexSet, to destination: Int)`
  - UserDefaults key `homelab_dashboard_card_order`

- [ ] **Step 1: Add property, key, init load, mutators**

In `Keys` enum add:

```swift
static let dashboardCardOrder = "homelab_dashboard_card_order"
```

Add property (mirror `serviceOrder` pattern):

```swift
private(set) var dashboardCardOrder: [DashboardCardID] {
    didSet {
        UserDefaults.standard.set(dashboardCardOrder.map(\.rawValue), forKey: Keys.dashboardCardOrder)
    }
}
```

In `init()`, after service order load:

```swift
let savedCardOrder = UserDefaults.standard.stringArray(forKey: Keys.dashboardCardOrder) ?? []
self.dashboardCardOrder = DashboardCardID.normalizeOrder(rawValues: savedCardOrder)
```

Add methods:

```swift
func setDashboardCardOrder(_ order: [DashboardCardID]) {
    dashboardCardOrder = DashboardCardID.normalizeOrder(order)
}

func moveDashboardCard(from source: IndexSet, to destination: Int) {
    var updated = dashboardCardOrder
    updated.move(fromOffsets: source, toOffset: destination)
    dashboardCardOrder = DashboardCardID.normalizeOrder(updated)
}

func resetDashboardCardOrder() {
    dashboardCardOrder = DashboardCardID.defaultOrder
}
```

- [ ] **Step 2: Sanity-check compile (optional quick)**

```bash
cd HomelabSwift
xcodebuild build -project Homelab.xcodeproj -scheme Homelab -configuration Debug \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/homelab-ios-dd CODE_SIGNING_ALLOWED=NO
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 3: Commit**

```bash
git add HomelabSwift/Homelab/Stores/SettingsStore.swift
git commit -m "$(cat <<'EOF'
feat: persist home dashboard card order

Store reorderable metric card order in UserDefaults via SettingsStore.
EOF
)"
```

---

### Task 3: DiskTemperatureCard + remove generic TemperatureCard from home

**Files:**
- Create: `HomelabSwift/Homelab/Views/Dashboard/DiskTemperatureCard.swift`
- Modify: `HomelabSwift/Homelab/Views/Home/HomeView.swift` (stop using `TemperatureCard`)
- Delete (if unused after): `HomelabSwift/Homelab/Views/Dashboard/TemperatureCard.swift`
- Modify localization files for title string if using Localizer (or hardcode zh temporarily then localize in Task 5 — **prefer localize in Task 5**; for this task use `localizer` only if keys already exist)

**Interfaces:**
- Consumes: `DashboardSystemStore`, `DashboardRefreshCoordinator`, `ServicesStore`, `DiskTemperatureSensorFilter`
- Produces: `struct DiskTemperatureCard: View` that lists disk sensors or shows muted empty (parent may hide when empty — see HomeView Task 4)

- [ ] **Step 1: Implement DiskTemperatureCard**

Mirror structure of existing `TemperatureCard.swift` but:

```swift
import SwiftUI

struct DiskTemperatureCard: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Environment(DashboardRefreshCoordinator.self) private var coordinator
    @Environment(DashboardSystemStore.self) private var systemStore

    @State private var sensors: [(name: String, celsius: Double)] = []

    var body: some View {
        DashboardCard(title: "硬盘温度", icon: "externaldrive.fill.badge.thermometer") {
            if sensors.isEmpty {
                Text("无数据")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ForEach(sensors, id: \.name) { sensor in
                    HStack {
                        Text(sensor.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(sensor.celsius))°C")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(temperatureColor(sensor.celsius))
                    }
                }
            }
        }
        .task(id: coordinator.refreshTrigger) {
            await fetch()
        }
        .opacity(sensors.isEmpty ? 0.55 : 1)
    }

    private func temperatureColor(_ celsius: Double) -> Color {
        if celsius > 80 { return AppTheme.stopped }
        if celsius > 60 { return AppTheme.warning }
        return AppTheme.running
    }

    private func fetch() async {
        await systemStore.refresh(servicesStore: servicesStore)
        guard let systemId = systemStore.firstSystemId,
              let instance = servicesStore.preferredInstance(for: .beszel),
              let client = await servicesStore.beszelClient(instanceId: instance.id) else {
            sensors = []
            return
        }
        do {
            let recordsResponse = try await client.getSystemRecords(systemId: systemId, limit: 1)
            guard let latest = recordsResponse.items.first?.stats else {
                sensors = []
                return
            }
            sensors = DiskTemperatureSensorFilter.diskSensors(from: latest.temperatureSensors)
        } catch {
            sensors = []
        }
    }
}
```

Replace hardcoded Chinese with Localizer keys in Task 5 if preferred for one-shot polish.

- [ ] **Step 2: Ensure HomeView does not reference TemperatureCard**

In Task 4 grid wiring use `DiskTemperatureCard` only. If current `HomeView` still has `TemperatureCard()`, remove that line now.

- [ ] **Step 3: Delete TemperatureCard.swift if no references**

```bash
rg -n "TemperatureCard" HomelabSwift
# if only the file itself matches, delete it and remove from pbxproj
```

- [ ] **Step 4: Compile**

```bash
cd HomelabSwift
xcodebuild build -project Homelab.xcodeproj -scheme Homelab -configuration Debug \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/homelab-ios-dd CODE_SIGNING_ALLOWED=NO
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 5: Commit**

```bash
git add HomelabSwift/Homelab/Views/Dashboard/DiskTemperatureCard.swift \
  HomelabSwift/Homelab/Views/Dashboard/TemperatureCard.swift \
  HomelabSwift/Homelab/Views/Home/HomeView.swift \
  HomelabSwift/Homelab.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: replace home temperature card with disk temperatures

Show Beszel disk-like sensors only; drop generic multi-sensor temp card.
EOF
)"
```

---

### Task 4: HomeView reorderable metric grid (PVE-style sections)

**Files:**
- Modify: `HomelabSwift/Homelab/Views/Home/HomeView.swift`

**Interfaces:**
- Consumes: `settingsStore.dashboardCardOrder`, `moveDashboardCard`, existing cards
- Produces: Home layout:
  1. Header Homelab (+ optional existing service order button)
  2. `SystemHealthCard` full width
  3. Reorderable 2-column metric cards from `dashboardCardOrder`
  4. `ServiceEntryCard` full width (or keep WIP HStack with Docker — **prefer**: Docker is a reorderable card; ServiceEntry full width below)

**Layout decision (lock this in):**
- `docker` is a **grid card** (participates in drag order)
- `ServiceEntryCard` is **full width below** the grid (not inside drag order)
- Do **not** place Docker and ServiceEntry in a permanent non-reorderable HStack once grid is done (WIP may have that HStack — replace it)

- [ ] **Step 1: Rewrite body content stack**

Replace the metric section roughly as:

```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                SystemHealthCard()
                    .padding(.horizontal, 16)

                metricGrid
                    .padding(.horizontal, 16)

                ServiceEntryCard(selectedNewServiceType: $showLogin)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 40)
        }
        // ... existing background, sheets, destinations unchanged
    }
    // ... environments, onAppear coordinator
}

@ViewBuilder
private var metricGrid: some View {
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    LazyVGrid(columns: columns, spacing: 12) {
        ForEach(settingsStore.dashboardCardOrder) { cardID in
            cardView(for: cardID)
                .id(cardID)
        }
    }
}
```

Wire `@Environment(SettingsStore.self)` if not already present (HomeView already uses `settingsStore` for ServiceOrderSheet).

- [ ] **Step 2: cardView switch**

```swift
@ViewBuilder
private func cardView(for id: DashboardCardID) -> some View {
    switch id {
    case .cpu: CPUMonitorCard()
    case .memory: MemoryMonitorCard()
    case .disk: DiskMonitorCard()
    case .diskTemperature: DiskTemperatureCard()
    case .docker: DockerOverviewCard()
    }
}
```

- [ ] **Step 3: Drag reorder UX**

Implement one of the following (pick **A** if it compiles cleanly on iOS 26):

**Option A — edit mode list strip (reliable):**  
Add toolbar/header button `arrow.up.arrow.down.circle` opening a sheet `DashboardCardOrderSheet` listing cards with `onMove`:

```swift
private struct DashboardCardOrderSheet: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(settingsStore.dashboardCardOrder) { id in
                    Text(title(for: id))
                }
                .onMove { source, dest in
                    settingsStore.moveDashboardCard(from: source, to: dest)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("卡片顺序")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("重置") { settingsStore.resetDashboardCardOrder() }
                }
            }
        }
    }

    private func title(for id: DashboardCardID) -> String {
        switch id {
        case .cpu: return "CPU"
        case .memory: return "内存"
        case .disk: return "磁盘"
        case .diskTemperature: return "硬盘温度"
        case .docker: return "Docker"
        }
    }
}
```

Expose sheet from header (can reuse or sit next to existing service-order button). Design required **drag** — List `onMove` is the standard iOS drag reorder and satisfies the requirement without fighting ScrollView.

**Option B — in-grid drag:** only if Option A is rejected in review; use `.draggable` / `.dropDestination` on each card.

This plan **standardizes on Option A** (sheet + onMove) for reliability.

- [ ] **Step 4: Header still shows service reorder; add card order button**

```swift
// next to existing showingServiceOrder button:
Button {
    HapticManager.light()
    showingCardOrder = true
} label: {
    Image(systemName: "rectangle.3.group")
    // styling match existing circle button
}
.accessibilityLabel("调整监控卡片顺序")
```

- [ ] **Step 5: Compile**

Same `xcodebuild build` as AGENTS.md. Expected: **BUILD SUCCEEDED**

- [ ] **Step 6: Commit**

```bash
git add HomelabSwift/Homelab/Views/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
feat: reorderable home metric grid in PVE-style layout

Stack system health, ordered metric cards, then service entry;
card order editable via drag list sheet.
EOF
)"
```

---

### Task 5: Localization (Homelab title, Home tab, card order copy)

**Files:**
- Modify: `HomelabSwift/Homelab/Localization/Translations.swift`
- Modify: `HomelabSwift/Homelab/Localization/Translations+Chinese.swift`
- Modify: `HomelabSwift/Homelab/Localization/Translations+English.swift`
- Modify: views that hardcode Chinese titles if switching to keys (`DiskTemperatureCard`, order sheet)

**Interfaces:**
- Produces keys (add any missing):
  - `launcherTitle`: zh `Homelab`, en `Homelab`
  - `tabHome`: zh `首页`, en `Home`
  - `homeReorderCards` / `homeResetCardOrder` / `homeDiskTemperature` / `homeNoData` as needed

- [ ] **Step 1: Change existing keys**

Chinese:

```swift
tabHome: "首页",
launcherTitle: "Homelab",
```

English:

```swift
tabHome: "Home",
launcherTitle: "Homelab",
```

- [ ] **Step 2: Add new keys to all three Translation files**

Example additions to `Translations.swift` struct:

```swift
let homeReorderCards: String
let homeResetCardOrder: String
let homeDiskTemperature: String
let homeNoSensorData: String
```

Chinese:

```swift
homeReorderCards: "监控卡片顺序",
homeResetCardOrder: "重置",
homeDiskTemperature: "硬盘温度",
homeNoSensorData: "无数据",
```

English:

```swift
homeReorderCards: "Card Order",
homeResetCardOrder: "Reset",
homeDiskTemperature: "Disk Temp",
homeNoSensorData: "No data",
```

Wire `DiskTemperatureCard` and order sheet to `localizer.t.*`.

- [ ] **Step 3: Compile**

Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add HomelabSwift/Homelab/Localization/ \
  HomelabSwift/Homelab/Views/Home/HomeView.swift \
  HomelabSwift/Homelab/Views/Dashboard/DiskTemperatureCard.swift
git commit -m "$(cat <<'EOF'
docs: rename home tab to Homelab dashboard copy

Replace service-overview branding with Homelab / Home strings.
EOF
)"
```

(Use `feat:` if preferred; copy-only is fine as `docs:` or `feat:` — prefer `feat: localize home dashboard polish strings`.)

---

### Task 6: Arcane username field + canSubmit

**Files:**
- Modify: `HomelabSwift/Homelab/Views/ServiceLogin/ServiceLoginView.swift`

**Interfaces:**
- Consumes: existing `needsUsername`, `case .arcane` submit path (WIP may already have `case .arcane`)
- Produces: username field visible for Arcane; can submit with user+pass or API key

- [ ] **Step 1: Add `.arcane` to `needsUsername`**

```swift
private var needsUsername: Bool {
    serviceType == .beszel
        || serviceType == .gitea
        // ... existing ...
        || serviceType == .openlist
        || serviceType == .arcane
}
```

- [ ] **Step 2: Tighten `canSubmit` for Arcane**

Inside `canSubmit`, before the generic `if !isProxmox { return true }` early path, handle Arcane:

```swift
if serviceType == .arcane {
    let hasKey = normalizedOptional(apiKey) != nil
        || (isEditing && !(existingInstance?.apiKey?.isEmpty ?? true))
    let hasUser = normalizedOptional(username) != nil
        || (isEditing && !(existingInstance?.username?.isEmpty ?? true))
    let hasPass = normalizedOptional(password) != nil
        || (isEditing && !(existingInstance?.password?.isEmpty ?? true))
    return hasKey || (hasUser && hasPass)
}
```

Ensure password field is shown for Arcane (not only when `needsUsername` — password is already shown for non-api-key types in formSection; verify Arcane is not stuck in `usesApiKeyAuth` only path).

If form currently hides password when only API key path is used: show **both** API key (optional) and username+password for Arcane. Pattern: treat Arcane like dual-mode — add a small branch in `formSection`:

```swift
// Pseudocode for form: if serviceType == .arcane {
//   apiKey field (optional)
//   username field
//   password field
// }
```

Read current `formSection` carefully; if `usesApiKeyAuth` excludes arcane and `needsUsername` now includes it, username+password fields appear; ensure API key field also available for Arcane by special-case:

```swift
if serviceType == .arcane {
    // show api key field (optional) then fall through to username/password
}
```

Implement minimal UI so both auth modes work without removing existing `case .arcane` submit logic.

- [ ] **Step 3: Manual logic check**

- New Arcane + only user/pass → canSubmit true  
- New Arcane + only api key → canSubmit true  
- New Arcane + empty → false  

- [ ] **Step 4: Compile**

Expected: **BUILD SUCCEEDED**

- [ ] **Step 5: Commit**

```bash
git add HomelabSwift/Homelab/Views/ServiceLogin/ServiceLoginView.swift
git commit -m "$(cat <<'EOF'
fix: show username when adding Arcane service

Arcane password login requires username; dual-mode with API key remains.
EOF
)"
```

---

### Task 7: Per-service URL placeholders

**Files:**
- Modify: `HomelabSwift/Homelab/Models/ServiceType.swift`
- Modify: `HomelabSwift/Homelab/Views/ServiceLogin/ServiceLoginView.swift`

**Interfaces:**
- Produces: `var urlPlaceholder: String` on `ServiceType`
- Login URL field uses `serviceType.urlPlaceholder` instead of generic `loginUrlPlaceholder` (except UniFi site manager special case)

- [ ] **Step 1: Add urlPlaceholder to ServiceType**

```swift
public var urlPlaceholder: String {
    switch self {
    case .beszel: return "http://beszel.local:8090"
    case .arcane: return "http://arcane.local:3552"
    case .portainer: return "https://portainer.local:9443"
    case .proxmox: return "https://pve.local:8006"
    case .truenas: return "https://truenas.local"
    case .openlist: return "http://openlist.local:5244"
    case .pihole: return "http://pi.hole"
    case .adguardHome: return "http://adguard.local"
    case .nginxProxyManager: return "http://npm.local:81"
    case .healthchecks: return "https://healthchecks.local"
    case .gitea: return "https://gitea.local"
    case .qbittorrent: return "http://qbittorrent.local:8080"
    case .plex: return "http://plex.local:32400"
    case .radarr: return "http://radarr.local:7878"
    case .sonarr: return "http://sonarr.local:8989"
    case .lidarr: return "http://lidarr.local:8686"
    case .jellystat: return "http://jellystat.local"
    case .uptimeKuma: return "http://uptime-kuma.local:3001"
    case .dockhand: return "http://dockhand.local"
    case .dockmon: return "http://dockmon.local"
    case .komodo: return "http://komodo.local"
    case .pangolin: return "http://pangolin.local"
    case .patchmon: return "http://patchmon.local"
    case .technitium: return "http://technitium.local"
    case .wakapi: return "http://wakapi.local"
    case .pterodactyl: return "https://panel.local"
    case .calagopus: return "http://calagopus.local"
    case .craftyController: return "https://crafty.local:8443"
    case .unifiNetwork: return "https://unifi.local"
    case .maltrail: return "http://maltrail.local"
    case .linuxUpdate: return "http://linux-update.local"
    case .jellyseerr: return "http://jellyseerr.local:5055"
    case .prowlarr: return "http://prowlarr.local:9696"
    case .bazarr: return "http://bazarr.local:6767"
    case .gluetun: return "http://gluetun.local:8000"
    case .flaresolverr: return "http://flaresolverr.local:8191"
    }
}
```

Ensure switch is exhaustive for all `ServiceType` cases.

- [ ] **Step 2: Use in ServiceLoginView URL field**

Replace generic placeholder for main URL (keep UniFi override):

```swift
placeholder: serviceType == .unifiNetwork && unifiAuthMode == .siteManager
    ? localizer.t.unifiSiteManagerURLPlaceholder
    : serviceType.urlPlaceholder,
```

- [ ] **Step 3: Compile**

Expected: **BUILD SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add HomelabSwift/Homelab/Models/ServiceType.swift \
  HomelabSwift/Homelab/Views/ServiceLogin/ServiceLoginView.swift
git commit -m "$(cat <<'EOF'
feat: per-service default URL placeholders on login

Show host:port examples for each service type instead of a generic hint.
EOF
)"
```

---

### Task 8: OpenSpec home-dashboard-overview semantics

**Files:**
- Modify: `openspec/specs/home-dashboard-overview/spec.md`

**Interfaces:**
- Produces: requirements aligned with Homelab dashboard (not 服务总览 title mandate)

- [ ] **Step 1: Rewrite requirements**

Replace Purpose TBD and outdated requirements with at least:

1. First tab is home dashboard; title Homelab; tab label 首页/Home  
2. Tab order unchanged: Home → Media → Bookmarks → Settings  
3. Layout: system health + metric cards + service entry; no fabricated metrics  
4. Beszel-primary system metrics; hide when unconfigured  
5. Monitor cards reorderable and persisted  
6. No PVE metrics block on home  
7. Disk temperature from disk-like sensors only (not generic all-sensors card)

Write concrete Scenario blocks (WHEN/THEN) matching OpenSpec style in the existing file.

- [ ] **Step 2: Commit**

```bash
git add openspec/specs/home-dashboard-overview/spec.md
git commit -m "$(cat <<'EOF'
docs: update home-dashboard-overview for Homelab metrics layout

Align main OpenSpec with drag-reorder cards and Beszel-first dashboard.
EOF
)"
```

---

### Task 9: Final verification

**Files:** none new (verification only)

- [ ] **Step 1: Unit tests**

```bash
cd HomelabSwift
xcodebuild test \
  -project Homelab.xcodeproj \
  -scheme Homelab \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/homelab-ios-test \
  -only-testing:HomelabTests/DashboardCardOrderTests \
  -only-testing:HomelabTests/DiskTemperatureSensorFilterTests
```

Expected: **TEST SUCCEEDED**

- [ ] **Step 2: Full iOS compile**

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

Expected: **BUILD SUCCEEDED**

- [ ] **Step 3: Manual checklist (document in commit message or leave for user)**

- [ ] Title Homelab; tab 首页/Home  
- [ ] No「服务总览」primary copy  
- [ ] No generic temperature card; disk temp when sensors exist  
- [ ] CPU / memory / disk / Docker with real sources only  
- [ ] Card order sheet drag persists after kill  
- [ ] Service entry includes Beszel add; PVE entry only (no PVE stats)  
- [ ] Arcane username+password can add  
- [ ] URL placeholders show service-specific defaults  

- [ ] **Step 4: Final commit only if leftover fixes**

```bash
git status
# if clean, skip; else commit remaining polish
```

---

## Spec coverage self-review

| Design requirement | Task |
|--------------------|------|
| Homelab title / Home tab | Task 5 |
| PVE-style sections | Task 4 |
| Beszel-primary metrics | Task 3–4 (existing cards + store) |
| Remove generic temp; disk temp | Task 3 |
| No ZFS / no OMV | — explicit non-work |
| No PVE metrics on home | Task 4 (no PVE cards added) |
| Drag reorder cards + persist | Task 1–2, 4 |
| Service entry kept; Beszel addable | Task 4 (`ServiceEntryCard`, homeServices already has beszel) |
| Arcane username | Task 6 |
| URL placeholders | Task 7 |
| OpenSpec update | Task 8 |
| iOS only | Global constraints |
| Tests + compile | Task 1, 9 |

## Placeholder scan

- No TBD steps; commands and code are concrete.
- Drag uses Option A sheet (`onMove`) as the locked interaction (design said “drag”; List reorder is drag handles).

## Type consistency

- `DashboardCardID` cases: `cpu`, `memory`, `disk`, `diskTemperature`, `docker` — used in SettingsStore, HomeView, tests.
- `DiskTemperatureSensorFilter.diskSensors(from:)` — used in DiskTemperatureCard + tests.
- `SettingsStore.moveDashboardCard(from:to:)` / `resetDashboardCardOrder()` — used by order sheet.
