import Foundation

/// Pure display logic: turns a `BatterySnapshot` into the status-bar title
/// and the dropdown's rows. Strings, numbers and view-free data only — no
/// AppKit types — so every display decision is unit-tested (spec §6).
enum MenuContentFactory {
    struct StatusTitle: Equatable {
        let text: String
        let tier: TempTier
        /// SF Symbol shown beside the title while a temperature reading
        /// exists. `nil` for "No Battery" and for an unavailable reading,
        /// where the words say more than a glyph.
        let symbolName: String?

        /// VoiceOver's copy: the tier stated in words, so the state never
        /// rides on color alone.
        var accessibilityValue: String {
            switch tier {
            case .muted:
                return text == "No Battery" ? "No battery detected" : "Temperature unavailable"
            case .normal, .warm, .hot:
                return "Temperature \(text), \(tier.name.lowercased())"
            }
        }
    }

    /// The app's one glyph: a thermometer, because the number it fronts is a
    /// temperature, not a charge level.
    static let statusSymbolName = "thermometer.medium"

    /// Sections of the dropdown, in the order the registers are read.
    static let conditionSection = "Condition"
    static let nowSection = "Right now"
    static let lifetimeSection = "Lifetime (recorded)"

    // MARK: - Title

    static func makeTitle(from snapshot: BatterySnapshot?) -> StatusTitle {
        guard let snapshot else {
            return StatusTitle(text: "No Battery", tier: .muted, symbolName: nil)
        }
        if let temperature = liveTemperature(snapshot) {
            return StatusTitle(
                text: String(format: "%.1f°C", temperature),
                tier: Thresholds.temperatureTier(temperature),
                symbolName: statusSymbolName
            )
        }
        return StatusTitle(text: "—", tier: .muted, symbolName: nil)
    }

    // MARK: - Rows

    /// Row order is fixed by spec §6 — health first, lifetime last — with the
    /// thermal ruler sitting under the temperature it belongs to. Section
    /// heads group registers; they carry no data of their own.
    static func makeRows(from snapshot: BatterySnapshot?) -> [MenuRow] {
        guard let snapshot else {
            return [.message("No battery detected")]
        }

        let temperature = liveTemperature(snapshot)
        var rows: [MenuRow] = [
            .section(conditionSection),
            .metric(label: "Battery Health", value: healthValue(snapshot)),
            .metric(label: "Temperature", value: temperatureValue(temperature)),
            .scale(ThermalReading(temperatureC: temperature)),
            .metric(label: "Cycles", value: cyclesValue(snapshot)),
            .metric(label: "Capacity", value: capacityValue(snapshot)),
            .separator,
            .section(nowSection),
            .metric(label: "Charge", value: chargeValue(snapshot)),
        ]
        if let timeLeft = timeLeftValue(snapshot) {
            rows.append(.metric(label: "Time left", value: timeLeft))
        }
        rows.append(contentsOf: [
            .metric(label: "Power", value: powerValue(snapshot)),
            .separator,
            .section(lifetimeSection),
            .metric(label: "Average", value: temperatureOnly(snapshot.lifetimeAvgTempC)),
            .metric(label: "Maximum", value: temperatureOnly(snapshot.lifetimeMaxTempC)),
            .metric(label: "Minimum", value: temperatureOnly(snapshot.lifetimeMinTempC)),
            .separator,
            .action("Refresh", keyEquivalent: "r"),
            .separator,
            .action("Quit", keyEquivalent: "q"),
        ])
        return rows
    }

    // MARK: - Reading

    /// Live temperature, with the pack's fallback key the spec names (§6).
    private static func liveTemperature(_ s: BatterySnapshot) -> Double? {
        s.temperatureC ?? s.virtualTemperatureC
    }

    // MARK: - Formatters

    static func formatTime(minutes: Int?) -> String {
        guard let minutes, minutes > 0, minutes != 65535 else { return MenuValue.timeUnavailableText }
        if minutes >= 60 {
            return String(format: "~%dh %02dm", minutes / 60, minutes % 60)
        }
        return String(format: "~%dm", minutes)
    }

    static func formatTemperature(_ celsius: Double?) -> String {
        guard let celsius else { return MenuValue.unavailableText }
        return String(format: "%.1f °C", celsius)
    }

    // MARK: - Row bodies

    private static func healthValue(_ s: BatterySnapshot) -> MenuValue {
        guard let health = s.healthPercent else { return .unavailable() }
        let condition = Thresholds.healthCondition(health)
        return MenuValue(
            measurement: "\(Int(health.rounded()))%",
            note: condition.label,
            signal: .health(condition)
        )
    }

    private static func temperatureValue(_ celsius: Double?) -> MenuValue {
        guard let celsius else { return .unavailable(signal: .thermal(.muted)) }
        return MenuValue(
            measurement: String(format: "%.1f °C", celsius),
            signal: .thermal(Thresholds.temperatureTier(celsius))
        )
    }

    /// A bare temperature reading, no tier: the lifetime registers are history,
    /// not a live alarm.
    private static func temperatureOnly(_ celsius: Double?) -> MenuValue {
        guard let celsius else { return .unavailable() }
        return MenuValue(measurement: String(format: "%.1f °C", celsius))
    }

    private static func cyclesValue(_ s: BatterySnapshot) -> MenuValue {
        guard let cycles = s.cycleCount,
              let design = s.designCycleCount, design > 0
        else { return .unavailable() }
        let used = Int((Double(cycles) / Double(design) * 100).rounded())
        return MenuValue(
            measurement: "\(cycles) of \(design)",
            note: "(\(used)% used)"
        )
    }

    private static func capacityValue(_ s: BatterySnapshot) -> MenuValue {
        guard let full = s.fullChargeCapacityMAH,
              let design = s.designCapacityMAH, design > 0
        else { return .unavailable() }
        let percent = Int((Double(full) / Double(design) * 100).rounded())
        return MenuValue(
            measurement: "\(full) / \(design) mAh",
            note: "(\(percent)%)"
        )
    }

    private static func chargeValue(_ s: BatterySnapshot) -> MenuValue {
        guard let percent = s.chargePercent else { return .unavailable() }
        switch s.isCharging {
        case .some(true):
            return MenuValue(measurement: "\(percent)%", note: "Charging")
        case .some(false):
            return MenuValue(measurement: "\(percent)%", note: "Discharging")
        case .none:
            // Registry didn't say — don't claim a state we don't know.
            return MenuValue(measurement: "\(percent)%", note: "Unknown")
        }
    }

    /// Time remaining is only meaningful on battery: it exists as its own row,
    /// and it disappears rather than showing `n/a` when charging.
    private static func timeLeftValue(_ s: BatterySnapshot) -> MenuValue? {
        guard s.isCharging == .some(false) else { return nil }
        let minutes = s.timeRemainingMinutes ?? s.avgTimeToEmptyMinutes
        guard let minutes, minutes > 0, minutes != 65535 else { return nil }
        return MenuValue(measurement: formatTime(minutes: minutes))
    }

    private static func powerValue(_ s: BatterySnapshot) -> MenuValue {
        let voltage = s.voltageV.map { String(format: "%.1f V", $0) } ?? MenuValue.unavailableText
        let current = s.currentA.map { String(format: "%.2f A", $0) } ?? MenuValue.unavailableText
        return MenuValue(measurement: "\(voltage) · \(current)")
    }
}
