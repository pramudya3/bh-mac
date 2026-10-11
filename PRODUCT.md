# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

## Stack

Swift 6.4 (SwiftPM, `--build-system native`), AppKit programmatic — no storyboards, no
SwiftUI, zero external dependencies. macOS 13.0+ deployment target, developed on Apple
Silicon. Built with Swift CLI Tools only (no Xcode.app); the release binary is assembled
into `BHMac.app` by `scripts/make-app.sh`. Tests run through a small built-in MiniTest
harness (`Tests/BHMacTests/MiniTest.swift`), not XCTest, so the toolchain needs no XCTest.

## Users

Single, named user: the author. A developer/power user on an Apple Silicon MacBook who
pokes at battery condition several times a day — "is this heat normal while charging",
"how much life is left in this battery", "am I near a service decision". English UI.

## Product Purpose

A menu-bar-only macOS app that shows battery temperature at a glance, with battery health
one click away. Success, in the author's own terms: temperature visible in the menu bar
within one second of launch and updated every ~10 seconds with no user action; the dropdown
answers "how healthy is my battery" without opening any other app; no root, no Xcode.app,
no notarization, no telemetry; distribution is a local build.

## Positioning

The app reads the battery's own gas-gauge registers straight out of the IOKit registry
(`AppleSmartBattery` merged with `AppleSmartBatteryPack` → `BatteryData`) and computes
health from `FullChargeCapacity / DesignCapacity` — not the smoothed top-level
`MaxCapacity`, which reads 100 on a worn battery. The lifetime statistics it shows
(`LifetimeData`) are a record System Settings does not surface at all. One binary, no
daemon, no dependencies, no permissions.

## Operating Context

Lives in the macOS menu bar as an accessory app (LSUIElement=true, accessory activation
policy, no Dock icon). A 10-second `Timer` re-reads the registry; the menu re-reads again
the moment it opens, and `Refresh` (⌘R) forces a re-read on demand. Glance-first: the
status item is read from across a desk, the dropdown is read from 40 cm in normal working
light — light and dark, both. Build and edit loop is Swift CLI Tools + Zed +
sourcekit-lsp; auto-start at login is manual (System Settings → Login Items).

## Capabilities and Constraints

Confirmed functionality: live temperature with a three-tier color mapping (≤ 35 °C
Normal / systemGreen, ≤ 42 °C Warm / systemOrange, > 42 °C Hot / systemRed, muted shows
`.secondaryLabelColor`); health bands (≥ 80% Normal, 60–79% Replace Soon, < 60% Service);
cycles vs. `DesignCycleCount9C`; `FullChargeCapacity` vs `DesignCapacity`; charge percent
plus charging state and time remaining (`~9h 37m`, `~37m`, 65535 and 0 render `n/a`);
voltage and amperage; lifetime average/max/min temperature.

Confirmed technical constraints and traps (all pinned by tests):
- `Temperature` lives only in the pack's nested `BatteryData` dictionary, is
  centi-degrees (3459 → 34.59 °C); `LifetimeData` temperatures are deci-degrees (273 →
  27.3 °C); `Voltage` is mV.
- `Amperage` / `InstantAmperage` arrive as unsigned 64-bit values that are two's-complement
  `Int64` (negative = discharging); the result is in mA.
- Every IOKit call is isolated: a failed read yields `nil` fields rendered `N/A`, never a
  crash, and per-field optionality keeps one missing key from taking out a whole row.
- Is `IsCharging` absent, the app says `Unknown` rather than guessing.

Not in scope (YAGNI, confirmed): history file or sparkline, settings UI, notifications,
graphs window, localization, signing/notarization.

## Brand Commitments

No logo, no marketing assets, no established voice beyond the README's plain, factual
register. Binding visual constraint recorded 2026-10-11 (user's own words, recorded
without expansion): the redesign covers **the menu-bar item and the dropdown menu, fully
redesigned in place** — it stays an `NSMenu` utility, not a custom popover panel; the
visual world is a **precision instrument / lab gauge**; and it is **designed for the app's
actual scene only** (the menu-bar backdrop, light and dark) rather than an abstract
dual-appearance exercise.

## Evidence on Hand

Real `ioreg` data captured on the target machine (2026-10-10) and codified as the test
fixture in `Tests/BHMacTests/MenuContentFactoryTests.swift`: Temperature 3459,
VirtualTemperature 3459, DesignCapacity 4382 mAh, FullChargeCapacity 3511 mAh,
CycleCount 308, DesignCycleCount9C 1000, Voltage 12025 mV, InstantAmperage
18446744073709551357 (decodes to −259 mA), CurrentCapacity 81, TimeRemaining 577,
LifetimeData 273 / 461 / 58 deci-°C. Design spec and implementation plan in
`docs/superpowers/`. Nothing else exists: no photographs, no testimonials, no customer or
benchmark claims — future work must not fabricate any.

## Product Principles

1. The number is the interface. The status item answers first; everything else is one
   click away and answers second.
2. Read the battery's own registers. Every value shown is a real reading from the gas
   gauge; a missing register reads `N/A`, never an estimate.
3. No root, no dependencies, no telemetry. The whole product is one small binary.
4. Color carries the alarm, text carries the fact — the tier is never color-only.
5. Personal-use craft. This app is glanced at dozens of times a day; it should repay that
   attention with precision, not decorate it.

## Accessibility & Inclusion

System semantic colors throughout (`labelColor`, `secondaryLabelColor`, the
`systemGreen/Orange/Red` tiers), so the interface follows Dark Mode and increased contrast
without hand-tuned hex. Temperature tier is conveyed by color in the status item and by a
labeled thermal scale with written tier names in the menu, so the state is never color-only.
Numeric values use tabular figures so digit changes never reflow a row. Accessibility
properties on the status item are part of the deliverable.
