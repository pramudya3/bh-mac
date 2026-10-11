---
version: 1
slug: "sources-bhmac"
primary_target: "Sources/BHMac"
related_targets: ["Sources/BHMac/Thresholds.swift"]
---

## Scope and mode

Surface: the BHMac app's whole UI — the macOS status-bar item and the `NSMenu` dropdown it
opens. Mode: **Operate**. The user opens the menu to answer "how healthy is my battery" and
get back to work; glance-first, one click away, dozens of times a day.

Scope (pinned by the user, 2026-10-11): a **full redesign in place**. The status-bar item
and the dropdown are rebuilt as designed objects inside the existing `NSMenu`
architecture — no custom popover panel, no SwiftUI rewrite. Content, row order, values,
key equivalents and behavior stay exactly as the product spec fixes them; the redesign owns
hierarchy, alignment, typography, color discipline, and every state.

Audience: the author, on an Apple Silicon MacBook, in normal working light — light and dark,
both at once, since the menu bar carries no appearance of its own.

Ambient scene (the answer that settled light/dark): the app lives on the menu-bar backdrop,
not on a page of its own, and it carries both. No dual-appearance exercise, no invented
scene: every color is a system semantic color so the surface follows the system, and the one
authored material — the thermal scale — is drawn from the same tier colors.

Constraints: macOS 13.0+, AppKit only, zero dependencies, no Xcode.app, Swift CLI Tools
build. Menu rows must stay plain enough that a click on a row never feels like a dead zone.

## Direction contract

THESIS: The surface owns "the battery's own registers, read as an instrument": the status
item is one calibrated number in tabular figures, and the dropdown is the instrument's
faceplate — a two-column measurement register with a thermal scale, refusing the genre
default of an inline `Label — value` text list and the neon-dashboard sci-fi opposite.

OWN-WORLD: System neutrals everywhere except the thermal tier, which appears in exactly
three places: the status item, the live temperature value, and the thermal scale. Two
voices, never mixed — SF Pro for words (labels, section heads, status words), SF Mono for
every measured number. Values run tabular, right-aligned to a fixed margin edge; labels sit
left at a fixed column. No cards, no borders, no chrome: the dropdown's own material is the
faceplate.

STORY: Open the menu and the battery reads top to bottom — health, temperature placed on
its scale, cycles and capacity against design, what it is doing right now, then the
lifetime record the gauge kept. Every number is a register reading; nothing is smoothed and
nothing is estimated.

FIRST VIEWPORT: the menu opens at a fixed width. A section head, then the health row
("Battery Health" → "80% · Normal", the tier word in the health tier's color), then the
Temperature row: live value in SF Mono, and beneath it the signature — a hairline
three-segment thermal ruler spanning the menu's inner width, tick labels 35 and 42 marking
the tier boundaries, the current tier lit. Then charge and power, then the lifetime record
in its own section. Refresh and Quit sit at the foot on a quiet margin.

FORM: the brief's pinned world — **precision instrument / lab gauge**, a bench-instrument
faceplate. It stood first on my grounded list (bench instrument, flight-deck annunciator,
Swiss data table, darkroom gauge, radio printing, oscilloscope trace, kitchen scale); the
roll assigned candidate 3, seed key 1212fe43, and the brief's pin beats the roll. Raises
carried in, each named for its donor: **one data voice** (ikeda-datamatics, declined) —
every measured number is set in the same monospaced measurement face, no number borrows the
label face; **near-monochrome discipline** (digital-design-canon monochrome product
marketing, declined) — the tier accent lives in exactly three places and every other mark is
a system neutral; **nothing labeled twice** (saville catalog sleeve, declined) — the thermal
scale is the only owned plot, each metric is named once and read once; **margin-aligned
running numbers** (cassette j-card, declined) — values right-align to a fixed margin edge
and labels to a fixed column.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review,
the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## The signature element

The thermal scale: three hairline segments spanning the menu's inner width, boundary tick
labels at 35 °C and 42 °C, the current tier lit in its own color, the live temperature read
against it. It is the reason to open the menu rather than only glance at the menu bar, and
the one thing in the dropdown a neighboring utility could not copy without also copying the
thresholds.

## Unresolved

- Menu-bar symbol: `thermometer.medium` tinted per tier, shown only while a temperature
  reading exists. If it reads as weather rather than battery, the fallback is a bare number
  with no glyph.
- Row structure keeps every metric the spec fixes, in spec order, with the same values;
  section heads and the label/value split are presentation only.
