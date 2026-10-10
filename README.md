# BHMac — Battery Health Menu Bar

A menu-bar-only macOS app that shows **battery temperature** at a glance, with battery health details one click away. Built for personal use: no root, no Xcode.app, no notarization, no telemetry.

- **Menu bar:** live battery temperature, color-coded (green ≤ 35 °C, orange ≤ 42 °C, red above)
- **Dropdown:** health %, cycles vs. design life, capacities, charge/power, and lifetime stats recorded by the battery's own gas gauge

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
