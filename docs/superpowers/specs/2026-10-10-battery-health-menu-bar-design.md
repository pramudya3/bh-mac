# Design: bh-mac — Battery Health Menu Bar App

**Date:** 2026-10-10
**Status:** Approved for planning
**Path:** Architectural (new project)

---

## 1. Intent

Personal-use macOS app that lives in the menu bar and shows battery condition at a glance. Most important surface: **battery temperature in the menu bar**, color-coded. Dropdown gives details: health %, cycle count, capacities, charge state, power draw, and lifetime statistics recorded by the battery's own gas gauge.

Success criteria:
- Temperature visible in menu bar, updating every ~10 seconds, no user action needed.
- Detail menu answers "how healthy is my battery" without opening any other app.
- No root/sudo required. No Xcode.app required to build or run.
- English UI.

## 2. Confirmed Constraints

| Decision | Choice |
|---|---|
| Tech stack | Swift native, AppKit programmatic (no storyboards, no SwiftUI) |
| Mac | Apple Silicon, macOS 27 (deployment target set to 13.0 for safety) |
| Data source | IOKit registry, no root: `AppleSmartBattery` service |
| Feature scope | Live details + color coding + gas-gauge lifetime stats (Approach A — Lean) |
| Distribution | Personal use, local build; no notarization, no signing |
| Editor/build | Swift CLI Tools 6.4 (`/usr/bin/swift`), Zed + sourcekit-lsp, `swift build` |
| UI language | English |

Not in scope (YAGNI): history file / sparkline, settings UI, notifications, graphs window, localization.

## 3. Environment Findings (verified 2026-10-10 on target machine)

Toolchain: Swift 6.4 at `/usr/bin/swift`; `xcode-select -p` → `/Library/Developer/CommandLineTools`; Zed at `/opt/homebrew/bin/zed`.

`ioreg -l -r -c AppleSmartBattery` works without root. Available data:

**Top-level keys** (on the `AppleSmartBattery` service — live charge state):
- `MaxCapacity` (gauge %, reads 100), `CurrentCapacity` (charge %)
- `CycleCount` = 308, `DesignCycleCount9C` = 1000 (design cycle life)
- `Voltage` = 12025 mV, `Amperage` / `InstantAmperage` (see §7 for encoding trap)
- `IsCharging`, `FullyCharged`, `ExternalConnected`, `TimeRemaining` (minutes), `AvgTimeToEmpty`
- `Serial`, `DeviceName` (`bq20z451`), `MaxCapacity`

**Nested `BatteryData` dictionary** — **on the `AppleSmartBatteryPack` service, not on `AppleSmartBattery`** (verified via `IORegistryEntryCreateCFProperties` during Task 4; the reader reads both services and merges, pack winning):
- `Temperature` = 3459 centi-°C → 34.59 °C (live)
- `VirtualTemperature` = 3459 (fallback when `Temperature` absent)
- `DesignCapacity` = 4382 mAh, `FullChargeCapacity` = 3511 mAh, `NominalChargeCapacity` = 3641 mAh, `AppleRawMaxCapacity` = 3506
- `LifetimeData`: `AverageTemperature` = 273 (27.3 °C), `MaximumTemperature` = 461 (46.1 °C), `MinimumTemperature` = 58 (5.8 °C), `TemperatureSamples` = 533108, `TotalOperatingTime` = 33319. **Units: deci-degrees (°0.1 °C), unlike the live `Temperature` key which is centi-degrees.** Sibling `LifetimeData` fields keep their own scales (`MaximumChargeCurrent` = 2405 mA, `MaximumPackVoltage` = 13037 → centi-V 13.04 V).

Note: `system_profiler SPPowerDataType` reports Maximum Capacity 84% / Condition Normal — computed differently from `FullChargeCapacity/DesignCapacity` (80.1%). We use the IOKit ratio and our own condition label (§6) as the single source.

## 4. Architecture

Package `BHMac`, single executable target, zero external dependencies. Each module has one job and a testable seam:

```
BHMac/
  AppDelegate.swift            — app lifecycle: creates status item, starts timer
  MenuBarController.swift      — thin NSStatusBar/NSMenu layer (AppKit only)
  MenuContentFactory.swift     — PURE: BatterySnapshot → [MenuRow] description
  MenuRow.swift                — display model (enum: item(title, style) / separator)
  BatteryReader.swift          — thin IOKit seam: reads registry, calls parser
  BatterySnapshot.swift        — struct + PURE parser (dictionary → struct)
  Thresholds.swift             — constants: poll interval, temp tiers, health bands
scripts/make-app.sh            — assembles BHMac.app bundle from release binary
Tests/BHMacTests/
  ...                          — XCTest, pure modules fully covered (§9)
```

**Data flow:** `Timer(10s, main run loop)` → `BatteryReader.readSnapshot()` → `BatterySnapshot` → `MenuBarController.update(snapshot)` (title + color) ; on menu open → immediate read → `MenuContentFactory.makeRows(snapshot)` → render `NSMenu`.

Failure isolation: every IOKit call is wrapped; a failed read produces a snapshot whose optional fields are `nil` (rendered `N/A`), never throws, never crashes. Per-field optionality means one missing property affects only its row.

## 5. IOKit Reading Rules (implementation-critical)

1. Match BOTH `AppleSmartBattery` AND `AppleSmartBatteryPack` via `IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(...))` (return value is `io_service_t` — compare against `0` for "not found", it is NOT Optional). Live charge state (IsCharging, CurrentCapacity, CycleCount, DesignCycleCount9C, Voltage, InstantAmperage/Amperage, TimeRemaining, AvgTimeToEmpty) lives on `AppleSmartBattery`; the rich pack data (Temperature, VirtualTemperature, DesignCapacity, FullChargeCapacity, LifetimeData) lives in `AppleSmartBatteryPack`'s `BatteryData` dictionary — merge pack over service before parsing.
2. Read properties with `IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0)` (4 arguments in this SDK) — works without root on Apple Silicon.
3. `Temperature` must be read from the nested `BatteryData` dictionary, NOT top level (it does not exist at top level on this machine — this is the #1 trap).
4. Temperature units: **centi-degrees C** (3459 → 34.59 °C). Voltage: **mV** (12025 → 12.03 V).
5. Amperage trap: `Amperage` / `InstantAmperage` come back as huge unsigned values (e.g. 18446744073709551357) that are two's-complement `Int64`. Cast to `Int64` — negative = discharging, positive = charging. Do not `UInt64`-interpret or `abs()`. On this machine the value decodes to −259, in **mA**. Display amps with two decimals (e.g. `-0.26 A`). Prefer `InstantAmperage`, fallback `Amperage`.
6. `TimeRemaining` is minutes; use it for the "time left" display, with `AvgTimeToEmpty` as fallback. Treat 65535 (`AvgTimeToFull` on AC) as "calculating/n/a".
7. Health is computed ONLY from the mAh pair: `FullChargeCapacity / DesignCapacity` from the nested `BatteryData` dictionary. Do NOT use the top-level `MaxCapacity` key — it is a smoothed gauge value that reads 100 even on a worn battery.
8. Never assume any key exists. Every field is parsed defensively into an `Optional`.

## 6. Display Specification

### Menu bar title
- Format: `34.6°C` (one decimal). Color tier from thresholds below.
- No battery detected → `No Battery`, `.secondaryLabelColor`.
- Temperature unavailable → `—` with the color of whatever fallback data exists (charge %) or neutral.

### Temperature tiers (thresholds, advisory)
| Tier | Range | Color | Rationale |
|---|---|---|---|
| Normal | ≤ 35 °C | `.systemGreen` | typical idle/light use |
| Warm | 35–42 °C | `.systemOrange` | charging / moderate load |
| Hot | > 42 °C | `.systemRed` | heavy load / thermal pressure |

Constants in `Thresholds.swift` so they can be tuned without touching logic.

### Health label (from mAh ratio)
`healthPercent = FullChargeCapacity / DesignCapacity` (3511/4382 = 80.1%)

| Band | Label |
|---|---|
| ≥ 80% | Normal |
| 60–79% | Replace Soon |
| < 60% | Service |

### Dropdown menu rows (order fixed)
1. `Battery Health — 80% · Normal` (title style)
2. `Temperature — 34.6 °C`
3. `Cycles — 308 of 1000 (31% used)`
4. `Capacity — 3511 / 4382 mAh (80%)`
5. `Charge — 81% · Discharging · ~9h 37m left` (or `· Charging`; time = `TimeRemaining`, fallback `AvgTimeToEmpty`)
6. `Power — 12.0 V · -0.26 A`
7. `Lifetime (recorded) — Avg 27.3°C · Max 46.1°C · Min 5.8°C` (deci-°C source, see §3)
8. separator
9. `Refresh` (enabled action — immediate re-read)
10. separator
11. `Quit` (⌘Q, terminates app)

Rows 1–7 are disabled info rows. Every numeric row falls back to `N/A` individually. Time remaining formatted `~9h 37m`; under 1h → `~37m`.

## 7. Error Handling

| Condition | Behavior |
|---|---|
| No `AppleSmartBattery` (desktop Mac) | Title `No Battery`; menu shows one row `No battery detected`; app idles, no crash |
| IOKit read fails | That tick's fields `nil` → `N/A`; error logged to stderr; retried next tick |
| `Temperature` missing | Fallback `VirtualTemperature`; if absent, row `N/A` and title `—` |
| Unexpected value ranges (e.g. 65535) | Render as `n/a`, never as a bogus number |

## 8. Build & Run (no Xcode.app)

- Dev loop: `swift run BHMac` from project root (Zed + sourcekit-lsp for editing).
- Release: `swift build -c release`, then `scripts/make-app.sh` produces `BHMac.app`:
  - `Contents/MacOS/BHMac` (release binary)
  - `Contents/Info.plist`: `CFBundleName=BHMac`, `CFBundleIdentifier=local.BHMac`, `LSUIElement=true` (no Dock icon), `LSMinimumSystemVersion=13.0`
- Run: `open BHMac.app` or execute the binary directly.
- Auto-start at login: manual — System Settings → General → Login Items → add BHMac (documented in README; SMAppService intentionally not used).
- Tests: `swift test`.

## 9. Testing Strategy

`swift test` with XCTest, all pure:

1. **Parser** — fixture dictionary captured from the real `ioreg` output above → snapshot equals expected values (34.59 °C, 308 cycles, 4382 mAh design, 3511 full charge, 12.025 V, `InstantAmperage` 18446744073709551357 → Int64 −259, etc.).
2. **Amperage encoding** — unsigned wraparound value → negative Int64.
3. **Temperature fallback** — missing `Temperature` → uses `VirtualTemperature`; both missing → nil.
4. **Thresholds** — boundary values 35.0 and 42.0 map to expected tiers.
5. **Health bands** — 80.1% → Normal, 65% → Replace Soon, 55% → Service.
6. **Formatting** — temperature one decimal; time `~9h 37m` / `~37m`; 65535 → `n/a`.
7. **MenuContentFactory** — full snapshot → expected `[MenuRow]` sequence; partial snapshot (single nil field) → that row `N/A`, others intact; no-battery snapshot → single explanatory row.
8. **BatteryReader mock** — protocol seam: feed snapshot → MenuBarController state logic (title string + color + row count) verified without touching IOKit.

Manual smoke test only (not automated): run the built app, confirm menu bar shows a plausible temperature that rises during charge/heavy load.

## 10. Manual Verification Checklist (end of implementation)

- [ ] `swift build` clean, no warnings-as-errors
- [ ] `swift test` all green
- [ ] `swift run BHMac` shows temp in menu bar within 1 second of launch
- [ ] Dropdown rows all show real values (no N/A on this machine)
- [ ] Title color matches current tier
- [ ] `scripts/make-app.sh` → `open BHMac.app` works, no Dock icon, appears in menu bar
- [ ] Quit works (⌘Q)
