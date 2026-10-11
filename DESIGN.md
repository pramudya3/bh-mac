---
name: "BHMac — Battery Health Menu Bar"
description: "A macOS menu-bar instrument: one calibrated reading in the status item, a fixed register of battery measurements behind it."
colors:
  label: "#000000"
  secondary-label: "#7F7F7F"
  separator: "#E8E8EA"
  tier-normal: "#34C759"
  tier-warm: "#FF9500"
  tier-hot: "#FF3B30"
typography:
  display:
    fontFamily: "-apple-system, SF Pro Text, sans-serif"
    fontSize: "13pt"
    fontWeight: "regular"
    fontFeature: "tabular numerals, fixed pitch digits"
    letterSpacing: "normal"
  body:
    fontFamily: "-apple-system, SF Pro Text, sans-serif"
    fontSize: "11pt"
    fontWeight: "regular"
  measurement:
    fontFamily: "SF Mono, Menlo, monospace"
    fontSize: "11pt"
    fontWeight: "medium"
  section-head:
    fontFamily: "-apple-system, SF Pro Text, sans-serif"
    fontSize: "10pt"
    fontWeight: "medium"
    letterSpacing: "0.06em"
    case: "uppercase"
  scale-tick:
    fontFamily: "SF Mono, Menlo, monospace"
    fontSize: "8.5pt"
    fontWeight: "regular"
rounded:
  track: "1.25pt"
  needle: "1.25pt"
  separator: "0.25pt"
spacing:
  row-width: "288pt"
  inset: "12pt"
  label-column: "104pt"
  label-value-gap: "8pt"
  metric-row: "24pt"
  section-row: "26pt"
  scale-row: "30pt"
  message-row: "22pt"
components:
  status-item:
    textColor: "{colors.tier-normal}"
    typography: "{typography.display}"
    height: "22pt"
  metric-row:
    textColor: "{colors.label}"
    typography: "{typography.body}"
    padding: "0 12pt"
    size: "{spacing.metric-row}"
  metric-row-label:
    textColor: "{colors.secondary-label}"
    typography: "{typography.body}"
  section-head:
    textColor: "{colors.secondary-label}"
    typography: "{typography.section-head}"
    padding: "0 12pt"
  thermal-scale:
    textColor: "{colors.label}"
    typography: "{typography.scale-tick}"
    size: "{spacing.scale-row}"
---

# Design System: BHMac

## Overview

**Creative North Star: "The Bench Instrument"**

BHMac is a measurement instrument that happens to live in a menu bar. It reads one register — the battery's own gas-gauge temperature — and displays it the way a bench instrument displays a reading: one voice for numbers, one voice for words, one accent for state, and nothing that is not a measurement. The whole product is two surfaces: a single live reading in the status item, and the fixed register behind it.

The instinct this world refuses is the genre default of a menu-bar utility: an icon pack, a colored battery glyph, and a text list of `Label — value` strings with no alignment, no hierarchy, and a decorative sparkline. Its opposite — the neon telemetry dashboard with glowing gauges and gratuitous data — is equally refused. A battery instrument should look like something you would trust to read correctly at a glance across a desk.

The status item carries the reading in tabular figures so a changing digit never reflows the menu bar, and a thermometer glyph in the tier's color because a bare number in a crowded menu bar is hard to find. The dropdown is a register: a fixed left column of names, a right-aligned column of readings on one shared edge, and one authored graphic — the thermal scale that places the live temperature against the two thresholds the app itself declares.

**Key Characteristics:**
- Two type voices, never mixed: the system face says words, the measurement face says numbers.
- One accent, spent only where state is reported: the status item, the live temperature, the thermal scale, and the health band word.
- The material is the menu's own: no background, no border, no card, no shadow is drawn.
- Fixed geometry. The register is 288pt wide with one label column, and every reading lands on the same right edge.

## Colors

The palette is Apple's semantic system colors, referenced by name in the code so Dark Mode and Increased Contrast resolve without hand-tuning. The hex values in the frontmatter are the light-appearance approximation, for tooling only.

### Primary
- **Normal** (`NSColor.systemGreen`): the Normal temperature tier (≤ 35 °C) and the Normal health band (≥ 80%). Appears in the status item, on the live temperature value, on the thermal scale's lit band, and on the health band word.
- **Warm** (`NSColor.systemOrange`): the Warm tier (35–42 °C) and the Replace Soon band (60–79%). Same four placements.
- **Hot** (`NSColor.systemRed`): the Hot tier (> 42 °C) and the Service band (< 60%). Same four placements.

### Neutral
- **Label** (`NSColor.labelColor`): measured values, action titles, and the thermal scale's needle. The one neutral that carries data.
- **Secondary Label** (`NSColor.secondaryLabelColor`): row labels, section heads, state words that carry no alarm, unavailable readings (`N/A`), and the scale's ticks — anything that names rather than reports.
- **Separator** (`NSColor.separatorColor`): the thermal scale's unfilled track and the menu's own section rules.

### Named Rules

**The One Accent Rule.** The tier palette is the only color in the product, and it is used in exactly four places: the status item, the live temperature value, the thermal scale, and the health band word. Everything else is a system neutral. A fifth use is a defect.

**The Never-Color-Only Rule.** Color is never the sole carrier of a state. Every tier is also written as a word (Normal / Warm / Hot on the status item's accessibility value; the health band word in the register), and the thermal scale states its thresholds as tick labels. The color is the alarm; the text is the message.

## Typography

**Display Font:** SF Pro Text via `NSFont.monospacedDigitSystemFont` — the system face forced to tabular digits, so the status item's width never jitters as the reading changes.
**Body Font:** SF Pro Text, the system UI face, for every word the product says.
**Label/Measurement Font:** SF Mono, for every number the product measures.

**Character:** A humanist sans for language, a monospace for data. The pairing is deliberately not decorative: the monospace exists so columns align and digits hold still, and it is used for measurements, tick labels, and readings — never as a costume for "technical" on words.

### Hierarchy
- **Display** (regular, 13pt, tabular digits): the status item's reading. The only type in the product sized for a glance across a desk.
- **Measurement** (medium, 11pt, SF Mono): every value in the register, from `80%` to `12.0 V · -0.26 A`.
- **Body** (regular, 11pt): row labels and state words. The wayfinding layer.
- **Section Head** (medium, 10pt, +0.06em tracking, uppercase): `CONDITION`, `RIGHT NOW`, `LIFETIME (RECORDED)`. Quiet, and set against the group it names rather than floating between groups.
- **Scale Tick** (regular, 8.5pt, SF Mono): the `35°` and `42°` boundary labels under the ruler.

### Named Rules

**The Two Voices Rule.** SF Pro speaks words; SF Mono speaks numbers. A number set in the system face, or a word set in the mono face, breaks the instrument's read and is a regression.

## Layout

The dropdown is a single fixed-width register, not a flowing menu. All rows share a 288pt width; labels sit in a 104pt column at a 12pt left inset; readings are right-aligned to a 12pt right inset, so every value in the product lands on one vertical edge. Row heights are fixed by kind — 24pt for a metric, 26pt for a section head, 30pt for the scale, 22pt for a plain line — which makes the menu's rhythm predictable rather than content-dependent.

Vertical spacing follows one rule: a section head has more air above it than below (8pt above, 5pt below), so the head sits against the group it opens instead of floating between two groups. Sections are separated by the menu's own hairline rules, drawn at half the inner width's inset.

There is no responsive layout to design. The product has one surface, one width, one device class, and a menu bar that supplies its own constraints. The width is wide enough for the longest reading (`308 of 1000 · (31% used)`) and no wider; longer readings truncate at the value column's edge rather than reflowing or pushing the register.

## Elevation & Depth

Flat, entirely. BHMac draws no shadows, no backgrounds, no borders and no translucency: the dropdown's depth is the menu's own system material, and adding anything on top of it would compete with the data. Depth between rows and sections is carried by typography, alignment, and the menu's own separators — which is exactly what an instrument does, where the faceplate has no depth of its own.

**The No-Chrome Rule.** If a mark is not a reading, a name, a rule, or a needle, it is not drawn. No card behind a row, no tinted band under a value, no icon for decoration.

## Shapes

The form language is hairline and round-ended. The thermal scale's track is a 2.5pt bar with 1.25pt corner radii; the needle that sits on it is 2.5pt wide and 11pt tall with 1.25pt corner radii, taller than the track so it reads as a marker rather than a continuation. Ticks are 1.5pt wide and 6pt tall, running above the track. The only other shape is the 0.5pt hairline the menu draws between sections. There are no cards, no boxes, and no containers anywhere in the product.

## Components

### Status Item
The live reading and nothing else. `NSStatusItem.variableLength` with the thermometer SF Symbol tinted in the tier's color, followed by the reading in tabular digits. The glyph disappears for `No Battery` and for an unavailable reading, where the words say more than a symbol; when a reading exists it is what makes the item findable in a crowded menu bar. VoiceOver reads the tier as a word, never as a color.

### Metric Row
- **Shape:** 288 × 24pt, transparent.
- **Label:** SF Pro 11pt regular, Secondary Label, left-aligned in the 104pt column.
- **Value:** SF Mono 11pt medium, Label color, right-aligned to the right inset. A state word follows in SF Pro 11pt (Secondary Label, or the tier color when it carries state), set off with a middle dot. Unavailable readings render `N/A` in Secondary Label — they never render a number we would have had to invent.

### Section Head
- **Shape:** 288 × 26pt, transparent, uppercase, +0.06em tracking, SF Pro 10pt medium in Secondary Label, with 8pt of air above and 5pt below.

### Thermal Scale
The product's one authored graphic, and the reason to open the menu rather than only glance at the menu bar. A hairline track spans the full inner width across a 20–50 °C domain. The tier the reading falls in lights its band in that tier's color; two ticks mark the app's own thresholds at 35 °C and 42 °C, each labelled underneath; a needle in Label color sits at the live reading. An unavailable reading lights nothing and shows no needle — the scale is still there to be read, it just has no state to report. The needle slides in from the left edge once per open over 240ms with an ease-out curve, and under Reduce Motion it appears at its reading without moving.

### Action Row
- **Refresh** (⌘R) and **Quit** (⌘Q): stock `NSMenuItem` rows at the foot of the menu, set in the menu font, with the menu's own separators above and between them. The register data never flows into an action row.

### Message Row
- The no-battery line, `No battery detected`, in Secondary Label at the label size, left-aligned. It is the only content in that menu, and it says what happened rather than showing an empty register.

## Do's and Don'ts

### Do:
- **Do** set every number in SF Mono at 11pt medium and every word in SF Pro at 11pt regular.
- **Do** right-align all readings to the 12pt right inset so they share one edge.
- **Do** reference colors by their semantic NSColor name (`labelColor`, `secondaryLabelColor`, `systemGreen`) so both appearances and Increased Contrast work without a hand-tuned hex.
- **Do** render a missing register as `N/A` in the measurement face, and omit a row (such as Time left on AC) rather than showing it as `n/a`.
- **Do** write the tier as a word in the status item's accessibility value, so state never rides on color alone.
- **Do** keep the register 288pt wide with a fixed 104pt label column.

### Don't:
- **Don't** draw a background, border, card, shadow or tint behind a row. The menu's material is the surface.
- **Don't** use the tier palette anywhere beyond the four named placements.
- **Don't** set a word in the monospace face or a number in the system face.
- **Don't** use a gradient, icon tile, progress ring or sparkline in place of the reading.
- **Don't** invent a value. A missing key renders `N/A`; an unknown charging state renders `Unknown`.
- **Don't** reorder the register: health first, temperature with its scale, then cycles, capacity, charge, power, and the lifetime record.
- **Don't** reflow the dropdown to fit a long reading — truncate it instead.
