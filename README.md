# BHMac — Battery Health Menu Bar

A menu-bar-only macOS app that shows **battery temperature** at a glance, with battery health details one click away. Built for personal use: no root, no Xcode.app, no notarization, no telemetry.

- **Menu bar:** live battery temperature, color-coded (green ≤ 35 °C, orange ≤ 42 °C, red above)
- **Dropdown:** health %, cycles vs. design life, capacities, charge/power, and lifetime stats recorded by the battery's own gas gauge
- **Ultra-low CPU & energy usage:** lazy dropdown rendering (zero AppKit view allocations while closed), dirty-checked status item updates, cached SF Symbols, and timer coalescing

## What the interface looks like

The menu bar carries a thermometer glyph and the live reading in tabular figures,
so a changing digit never reflows it. The glyph disappears when there is no
reading to back it up (`No Battery`, `—`).

The dropdown is a fixed register, not a text list:

| Section | Rows |
|---|---|
| **Condition** | Battery Health (percent + band word, colored), Temperature (value + the thermal scale beneath it), Cycles, Capacity |
| **Right now** | Charge (percent + state), Time left (on battery only), Power (voltage · amperage) |
| **Lifetime (recorded)** | Average, Maximum, Minimum temperature |

Values sit in the monospaced measurement face, labels in the system face, and
every reading lines up on one right edge. Missing registers render `N/A`.
Between `Refresh` (⌘R) and `Quit` (⌘Q) the register data never mixes with an action.

The thermal scale under the temperature row is the one authored graphic: a
hairline ruler over 20–50 °C with the live tier's band lit, tick labels at the
app's own 35 °C and 42 °C thresholds, and a needle at the reading that slides in
as the menu opens. Full design system in [DESIGN.md](DESIGN.md).

## Requirements

- macOS 13.0+ (developed and data-verified on Apple Silicon)
- Swift toolchain with CLI tools (`swift --version`) — **Xcode.app is not required**

## Build & run

```bash
# Run in place (debug)
swift run --build-system native BHMacApp

# Or build the app bundle
bash scripts/make-app.sh
open BHMac.app
```

Notes:
- `--build-system native` is required on machines where the default
  SwiftPM build engine fails to initialize (known on some CommandLineTools
  installs; drop the flag if the default engine works for you).
- `swift run BHMacApp` shows no Dock icon (the app requests the accessory
  activation policy); the bundle additionally sets `LSUIElement=true`.

## Auto-start at login (manual)

System Settings → General → Login Items → add `BHMac.app`.

## Tests

```bash
swift run --build-system native bhmac-tests
```

This project uses a small built-in harness (`Tests/BHMacTests/MiniTest.swift`)
instead of XCTest so it runs on toolchains without XCTest. Test names map 1:1
to the plan (parser, amperage encoding, unit conversions, thresholds,
formatting, menu rows, no-battery path, plus one live-machine IOKit read that
skips on desktops).

## How data is read

No root needed — the app reads two IOKit services and merges them:

| Service | What it provides |
|---|---|
| `AppleSmartBattery` | live state: `CurrentCapacity`, `CycleCount`, `DesignCycleCount9C`, `IsCharging`, `Voltage`, `InstantAmperage`/`Amperage`, `TimeRemaining` |
| `AppleSmartBatteryPack` → `BatteryData` | `Temperature`, `VirtualTemperature`, `DesignCapacity`, `FullChargeCapacity`, `LifetimeData` (avg/max/min temperature, samples) |

Unit traps the code handles (all pinned by tests):

- `Temperature` is centi-degrees (3459 → 34.59 °C); `LifetimeData` temperatures
  are **deci-degrees** (273 → 27.3 °C)
- `Voltage` is millivolts; amperage is stored as an unsigned 64-bit number whose
  real value is a signed `Int64` (negative = discharging)
- Health = `FullChargeCapacity / DesignCapacity` from the pack's `BatteryData`
  — not the smoothed top-level `MaxCapacity`, which reads 100 even on a worn battery

## Tuning

Open `Sources/BHMac/Thresholds.swift` — refresh interval, temperature tiers,
and health label bands are constants there.
