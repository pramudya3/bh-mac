# Brainstorming Progress — bh-mac (Battery Health Menu Bar App)

Path: **Architectural** (new project, empty repo)

## Jawaban user (terkonfirmasi)
1. Tech stack: **Swift native** (AppKit programmatic, tanpa SwiftUI storyboard)
2. Mac: **Apple Silicon**, macOS 27 (sesuai target toolchain)
3. Sumber data: **Tanpa root, via IOKit registry** (AppleSmartBattery)
4. Scope fitur: Detail baterai di dropdown + visual indicator/color coding + battery health tracking jangka panjang (histori)
5. Editor/build: **Tanpa Xcode.app** — Swift CLI Tools 6.4 + Zed + sourcekit-lsp; `.app` bundle dirakit manual (Info.plist + LSUIElement)
6. Personal use via build lokal

## Environment findings (probe read-only, 2026-10-10)
- Swift 6.4 di /usr/bin/swift; xcode-select → /Library/Developer/CommandLineTools; Zed di /opt/homebrew/bin/zed
- `ioreg -l -r -c AppleSmartBattery` — key top-level: MaxCapacity, CurrentCapacity, CycleCount, DesignCycleCount9C, Voltage, Amperage, IsCharging, TimeRemaining, FullyCharged, ExternalConnected, Serial, DeviceName
- **Temperature TIDAK ada di top-level** — ada di nested dict `BatteryData`: `Temperature` (centi-°C, live), `VirtualTemperature`, `LifetimeData` = {AverageTemperature, MinimumTemperature, MaximumTemperature, TemperatureSamples, TotalOperatingTime}
- Capacities: DesignCapacity=4382 mAh, FullChargeCapacity=3511, NominalChargeCapacity=3641, AppleRawMaxCapacity=3506
- CycleCount=308, DesignCycleCount9C=1000
- system_profiler SPPowerDataType = cross-check data (Maximum Capacity 84%, Condition Normal) — beda hitungan health vs IOKit, perlu diputuskan rumus health di spec

## Checklist
- [x] 1. Explore project context — repo kosong, proyek baru
- [x] 2. Clarifying questions (stack, Mac, data source, scope, distribusi)
- [ ] 2b. Sisa pertanyaan: bahasa UI, interval polling
- [ ] 3. Propose 2-3 approaches with trade-offs
- [ ] 4. Present design in sections, approval per section
- [ ] 5. Write design doc → `docs/superpowers/specs/2026-10-10-battery-health-menu-bar-design.md`
- [ ] 6. Spec self-review
- [ ] 7. User reviews written spec
- [ ] 8. Invoke writing-plans skill
