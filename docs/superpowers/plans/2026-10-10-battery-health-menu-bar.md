# BHMac — Battery Health Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A menu-bar-only macOS app (no Dock icon, no root, no Xcode.app) that shows live battery temperature color-coded, with a dropdown of battery health details.

**Architecture:** Single Swift executable target (AppKit programmatic). Pure modules (`Thresholds`, `BatterySnapshot`, `MenuContentFactory`) hold all logic and are covered by XCTest; thin adapters (`IOKitBatteryReader`, `MenuBarController`) touch the system; `AppDelegate` wires a 10s timer between them.

**Tech Stack:** Swift 6.4 CLI toolchain, AppKit/IOKit, SPM executableTarget + testTarget, XCTest. Zero external dependencies.

**Spec:** `docs/superpowers/specs/2026-10-10-battery-health-menu-bar-design.md`

## Global Constraints

- Swift tools 6.0; deployment target macOS 13.0; module name `BHMac`; test target `BHMacTests` with `@testable import BHMac`.
- No external package dependencies. No root/sudo. UI copy in English only. Bundle id `local.BHMac`, `LSUIElement=true`.
- Commit after every task: `git add` the task's files, message `feat: <what>` (or `chore:`/`test:` as appropriate).
- IOKit traps (from spec §5): `Temperature` lives inside the nested `BatteryData` dictionary (NOT top level); temperature is centi-°C; voltage is mV; `InstantAmperage` decodes as `Int64(bitPattern:)` of a `UInt64` (negative = discharging); never assume any key exists — every field is Optional.
- All numeric menu rows fall back to `N/A` individually; never crash on a missing key.

## Review Focus

- Desktop Mac with no `AppleSmartBattery` service → app must show `No Battery` and idle, not crash. Pinned: Task 3 (`makeTitle(from: nil)`, `makeRows(from: nil)`), Task 4 (live read returns nil).
- Every discharge reading carries the amperage unsigned-wraparound value → a wrong cast spews a 1.8e19 A reading. Pinned: Task 2.
- Individual property missing on other macOS versions (e.g. no `Temperature`) → only that row goes `N/A`, rest intact. Pinned: Tasks 2 & 3.
- Exactly-threshold temperatures 35.0 °C and 42.0 °C → tier boundaries must match spec (inclusive upper bound). Pinned: Task 1.
- IOKit placeholder values (e.g. `65535` = "calculating") → rendered `n/a`, never as bogus hours. Pinned: Task 3.

---

### Task 1: Package scaffold + Thresholds

**Files:**
- Create: `Package.swift`
- Create: `Sources/BHMac/main.swift` (temporary scaffold: `print("BHMac scaffold")`)
- Create: `Sources/BHMac/Thresholds.swift`
- Create: `Tests/BHMacTests/ThresholdsTests.swift`

**Interfaces:**
- Produces:
  - `enum TempTier: String { case muted, normal, warm, hot }`
  - `enum Thresholds` with `static let pollInterval: TimeInterval = 10`, `static let warmC: Double = 35.0`, `static let hotC: Double = 42.0`, `static let healthNormalMin: Double = 80.0`, `static let healthReplaceMin: Double = 60.0`, `static func temperatureTier(_ celsius: Double) -> TempTier` (≤ 35.0 → `.normal`; ≤ 42.0 → `.warm`; else `.hot`), `static func healthLabel(_ percent: Double) -> String` (≥ 80 → "Normal"; ≥ 60 → "Replace Soon"; else "Service")

- [ ] **Step 1: Write the failing tests** in `Tests/BHMacTests/ThresholdsTests.swift`:
  - `testTemperatureTierBoundaries`: 34.9 → `.normal`; 35.0 → `.normal`; 35.1 → `.warm`; 42.0 → `.warm`; 42.1 → `.hot`
  - `testHealthLabels`: 92.0 → "Normal"; 80.0 → "Normal"; 79.9 → "Replace Soon"; 60.0 → "Replace Soon"; 59.9 → "Service"
- [ ] **Step 2: Run `swift test --filter ThresholdsTests`** — expect FAIL (type not found).
- [ ] **Step 3: Create `Package.swift`** (executableTarget `BHMac`, testTarget `BHMacTests`, `.macOS(.v13)`) **and implement `Thresholds.swift`** per Interfaces above.
- [ ] **Step 4: Run `swift test --filter ThresholdsTests`** — expect PASS (9 assertions).
- [ ] **Step 5: Commit** — `git add Package.swift Sources/BHMac Tests/BHMacTests && git commit -m "chore: scaffold package + thresholds"`

---

### Task 2: BatterySnapshot parser

**Files:**
- Create: `Sources/BHMac/BatterySnapshot.swift`
- Create: `Tests/BHMacTests/BatterySnapshotTests.swift`

**Interfaces:**
- Produces `struct BatterySnapshot` with all-Optional `let` fields, each defaulted `= nil`: `temperatureC: Double?`, `virtualTemperatureC: Double?`, `healthPercent: Double?`, `designCapacityMAH: Int?`, `fullChargeCapacityMAH: Int?`, `chargePercent: Int?`, `cycleCount: Int?`, `designCycleCount: Int?`, `voltageV: Double?`, `currentA: Double?`, `isCharging: Bool?`, `timeRemainingMinutes: Int?`, `avgTimeToEmptyMinutes: Int?`, `lifetimeAvgTempC: Double?`, `lifetimeMaxTempC: Double?`, `lifetimeMinTempC: Double?`, `temperatureSamples: Int?`
  - `static func parse(from properties: [String: Any]) -> BatterySnapshot`
  - Health = `FullChargeCapacity / DesignCapacity * 100` from `BatteryData` only (never top-level `MaxCapacity`).
  - Amperage: try `InstantAmperage` then `Amperage`; decode `UInt64` → `Int64(bitPattern:)` → mA → A (`/1000.0`).
  - Temperature fallback chain lives in the factory, not here: parse both `Temperature` and `VirtualTemperature` into separate fields.

- [ ] **Step 1: Write the failing tests**, with a fixture dictionary of the real machine (values from spec §3):
  - `testParseRealFixture` → `temperatureC == 34.59`, `virtualTemperatureC == 34.59`, `healthPercent == 80.1` (±0.05), `designCapacityMAH == 4382`, `fullChargeCapacityMAH == 3511`, `chargePercent == 81`, `cycleCount == 308`, `designCycleCount == 1000`, `voltageV == 12.025` (±0.001), `currentA == -0.259` (±0.001), `isCharging == false`, `timeRemainingMinutes == 577`, `lifetimeAvgTempC == 27.3`, `lifetimeMaxTempC == 46.1`, `lifetimeMinTempC == 0.58`, `temperatureSamples == 533108`
  - `testAmperageUnsignedWraparound`: `["Amperage": UInt64(18446744073709551357)]` alone → `currentA == -0.259` (±0.001)
  - `testEmptyDictionaryYieldsAllNil`: `BatterySnapshot.parse(from: [:])` → every field nil
  - `testMissingBatteryDataLeavesOptionalsNil`: only top-level keys `["CycleCount": 308, "Voltage": 12025]` → `temperatureC == nil`, `healthPercent == nil`, `cycleCount == 308`
  - `testFallsBackToAmperageWhenInstantMissing`
- [ ] **Step 2: Run `swift test --filter BatterySnapshotTests`** — expect FAIL.
- [ ] **Step 3: Implement `BatterySnapshot.swift`** per Interfaces; helper `Int?` reader = `(value as? Int) ?? (value as? UInt64).map(Int.init)`, `Bool?` reader tries `as? Bool` then `as? Int == 0/1`.
- [ ] **Step 4: Run `swift test`** — expect PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat: battery snapshot parser"`

---

### Task 3: MenuRow + MenuContentFactory (pure display logic)

**Files:**
- Create: `Sources/BHMac/MenuRow.swift`
- Create: `Sources/BHMac/MenuContentFactory.swift`
- Create: `Tests/BHMacTests/MenuContentFactoryTests.swift`

**Interfaces:**
- Produces `enum MenuRow { case info(String); case action(String, keyEquivalent: String); case separator }`
- Produces `enum MenuContentFactory` with:
  - `struct StatusTitle { let text: String; let tier: TempTier }`
  - `static func makeTitle(from snapshot: BatterySnapshot?) -> StatusTitle` — nil → `StatusTitle(text: "No Battery", tier: .muted)`; temp present (`temperatureC ?? virtualTemperatureC`) → `"34.6°C"` + tier from `Thresholds.temperatureTier`; else `"—"` + `.muted`
  - `static func makeRows(from snapshot: BatterySnapshot?) -> [MenuRow]` — nil → `[.info("No battery detected")]`; else the 11 rows of spec §6 in exact order
  - `static func formatTime(minutes: Int?) -> String` — nil/≤0/65535 → `"n/a"`; ≥ 60 → `"~9h 37m"`; else `"~37m"`
  - `static func formatTemperature(_ celsius: Double?) -> String` — nil → `"N/A"`; else `"34.6 °C"` (one decimal)
- Consumes: `BatterySnapshot` (Task 2), `TempTier`/`Thresholds` (Task 1)

- [ ] **Step 1: Write the failing tests**:
  - `testFullSnapshotRows`: parse fixture → exact `[MenuRow]` equality with spec §6 strings (`"Battery Health — 80% · Normal"`, `"Temperature — 34.6 °C"`, `"Cycles — 308 of 1000 (31% used)"`, `"Capacity — 3511 / 4382 mAh (80%)"`, `"Charge — 81% · Discharging · ~9h 37m left"`, `"Power — 12.0 V · -0.26 A"`, `"Lifetime (recorded) — Avg 27.3°C · Max 46.1°C · Min 0.6°C"`, separator, `action("Refresh", keyEquivalent: "r")`, separator, `action("Quit", keyEquivalent: "q")`)
  - `testMissingTemperatureYieldsNARow`: snapshot with temperature fields nil → title `"—"`, `.muted`; rows contain `"Temperature — N/A"`, others identical to full-snapshot rows
  - `testNilSnapshotReturnsNoBattery`: `makeTitle(from: nil)` == `("No Battery", .muted)`; `makeRows(from: nil)` == `[.info("No battery detected")]`
  - `testFormatTimeBoundaries`: nil → "n/a"; 0 → "n/a"; 65535 → "n/a"; 37 → "~37m"; 577 → "~9h 37m"
  - `testChargingRowOmitsTimeLeft`: `isCharging = true` → row `"Charge — 81% · Charging"`
- [ ] **Step 2: Run `swift test --filter MenuContentFactoryTests`** — expect FAIL.
- [ ] **Step 3: Implement `MenuRow.swift` + `MenuContentFactory.swift`** per Interfaces (Foundation `String(format:)` for decimals; `.Equatable` synthesis must hold — keep `MenuRow` a simple enum, no payload structs).
- [ ] **Step 4: Run `swift test`** — expect PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat: menu content factory"`

---

### Task 4: IOKitBatteryReader

**Files:**
- Create: `Sources/BHMac/BatteryReader.swift`
- Create: `Tests/BHMacTests/BatteryReaderTests.swift`

**Interfaces:**
- Produces `protocol BatteryReading { func readSnapshot() -> BatterySnapshot? }` and `final class IOKitBatteryReader: BatteryReading`
  - `IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"))` → nil = no battery → return nil; `defer { IOObjectRelease(service) }`
  - `IORegistryEntryCreateCFProperties` → `takeRetainedValue() as? [String: Any]` → `BatterySnapshot.parse`
- Consumes: `BatterySnapshot` (Task 2)

- [ ] **Step 1: Write the failing test** (`Tests/BHMacTests/BatteryReaderTests.swift`):
  - `testReadSnapshotFromLiveMachine`: `IOKitBatteryReader().readSnapshot()` is nil → `throw XCTSkip("No AppleSmartBattery service (desktop Mac)")`; else `XCTAssertNotNil(snapshot.temperatureC)` and `XCTAssertNotNil(snapshot.cycleCount)`
- [ ] **Step 2: Run `swift test --filter BatteryReaderTests`** — expect FAIL (type not found).
- [ ] **Step 3: Implement `BatteryReader.swift`** (`import IOKit`) per Interfaces.
- [ ] **Step 4: Run `swift test`** — expect PASS (or Skip on battery-less machines).
- [ ] **Step 5: Commit** — `git commit -am "feat: IOKit battery reader"`

---

### Task 5: MenuBarController + StatusStyle

**Files:**
- Create: `Sources/BHMac/StatusStyle.swift`
- Create: `Sources/BHMac/MenuBarController.swift`
- Create: `Tests/BHMacTests/StatusStyleTests.swift`

**Interfaces:**
- Produces `enum StatusStyle { static func color(for tier: TempTier) -> NSColor }` — `.muted → .secondaryLabelColor`, `.normal → .systemGreen`, `.warm → .systemOrange`, `.hot → .systemRed`
- Produces `final class MenuBarController: NSObject, NSMenuDelegate`:
  - `var onMenuWillOpen: (() -> Void)?`
  - `func updateTitle(_ title: MenuContentFactory.StatusTitle)` — `attributedTitle` with `NSAttributedString` + `.foregroundColor = StatusStyle.color(for:)`
  - `func present(_ rows: [MenuRow])` — rebuild `NSMenu` each call: `.info` → disabled item; `.separator` → `.separator()`; `.action("Refresh")` → calls `onMenuWillOpen?()`; `.action("Quit", keyEquivalent: "q")` → `NSApp.terminate(nil)`
  - `func menuNeedsUpdate(_ menu: NSMenu)` → `onMenuWillOpen?()`
- Consumes: `MenuRow`, `MenuContentFactory.StatusTitle` (Task 3), `TempTier` (Task 1)

- [ ] **Step 1: Write the failing test** (`StatusStyleTests`): all four tier→color mappings (assert `color == NSColor.systemGreen` etc.)
- [ ] **Step 2: Run `swift test --filter StatusStyleTests`** — expect FAIL.
- [ ] **Step 3: Implement both files** (`import AppKit`) per Interfaces.
- [ ] **Step 4: Run `swift test`** — expect PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat: menu bar controller + status styling"`

---

### Task 6: AppDelegate wiring + app bundle + README

**Files:**
- Create: `Sources/BHMac/AppDelegate.swift`
- Modify: `Sources/BHMac/main.swift` (replace scaffold print)
- Create: `scripts/Info.plist`
- Create: `scripts/make-app.sh` (`chmod +x`)
- Create: `README.md`

**Interfaces:**
- Produces `final class AppDelegate: NSObject, NSApplicationDelegate` — `init(reader: BatteryReading = IOKitBatteryReader())`; `applicationDidFinishLaunching` sets `controller.onMenuWillOpen`, calls `refresh()`, starts `Timer.scheduledTimer(withTimeInterval: Thresholds.pollInterval, repeats: true)`; private `refresh()` = read → `updateTitle` + `present`
- `main.swift`: `NSApplication.shared` + `setActivationPolicy(.accessory)` + delegate + `app.run()`

- [ ] **Step 1: Replace `Sources/BHMac/main.swift`** with the bootstrap; create `AppDelegate.swift` per Interfaces.
- [ ] **Step 2: Run `swift build`** — expect clean build, no errors.
- [ ] **Step 3: Create `scripts/Info.plist`**: `CFBundleExecutable=BHMac`, `CFBundleIdentifier=local.BHMac`, `CFBundleName=BHMac`, `CFBundlePackageType=APPL`, `CFBundleShortVersionString=1.0`, `LSMinimumSystemVersion=13.0`, `LSUIElement=true`
- [ ] **Step 4: Create `scripts/make-app.sh`**: `.build/release/BHMac` → `BHMac.app/Contents/MacOS/` + copy Info.plist; `chmod +x`; run `bash scripts/make-app.sh` — expect `Built BHMac.app`.
- [ ] **Step 5: Verify bundle**: `plutil -lint BHMac.app/Contents/Info.plist` → "OK"; `swift test` → PASS.
- [ ] **Step 6: Write `README.md`**: build/run (`swift run BHMac`, `scripts/make-app.sh` + `open BHMac.app`), manual login-item steps, data source + unit notes, how to tune `Thresholds.swift`.
- [ ] **Step 7: Manual smoke test** (agent runs; human confirms): `open BHMac.app` → menu bar shows a plausible temperature (e.g. `31.5°C`); dropdown shows all rows without `N/A`; Quit works.
- [ ] **Step 8: Final checklist from spec §10**: clean `swift build`; green `swift test`; temp visible ≤ 1s; no Dock icon; title color matches tier; ⌘Q quits.
- [ ] **Step 9: Commit** — `git commit -am "feat: app wiring + bundle script + readme"`; `git log --oneline` shows all 6 task commits.
