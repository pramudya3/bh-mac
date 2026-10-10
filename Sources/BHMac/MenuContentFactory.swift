import Foundation

/// Pure display logic: turns a `BatterySnapshot` into the menu-bar title
/// and the dropdown rows. Strings and numbers only — no AppKit types — so
/// every format decision is unit-tested (spec §6).
enum MenuContentFactory {
    struct StatusTitle {
        let text: String
        let tier: TempTier
    }

    // MARK: - Title

    static func makeTitle(from snapshot: BatterySnapshot?) -> StatusTitle {
        guard let snapshot else {
            return StatusTitle(text: "No Battery", tier: .muted)
        }
        if let temperature = snapshot.temperatureC ?? snapshot.virtualTemperatureC {
            return StatusTitle(
                text: String(format: "%.1f°C", temperature),
                tier: Thresholds.temperatureTier(temperature)
            )
        }
        return StatusTitle(text: "—", tier: .muted)
    }

    // MARK: - Rows (order fixed by spec §6)

    static func makeRows(from snapshot: BatterySnapshot?) -> [MenuRow] {
        guard let snapshot else {
            return [.info("No battery detected")]
        }
        return [
            .info("Battery Health — \(healthLine(snapshot))"),
            .info("Temperature — \(formatTemperature(snapshot.temperatureC ?? snapshot.virtualTemperatureC))"),
            .info("Cycles — \(cyclesLine(snapshot))"),
            .info("Capacity — \(capacityLine(snapshot))"),
            .info("Charge — \(chargeLine(snapshot))"),
            .info("Power — \(powerLine(snapshot))"),
            .info("Lifetime (recorded) — \(lifetimeLine(snapshot))"),
            .separator,
            .action("Refresh", keyEquivalent: "r"),
            .separator,
            .action("Quit", keyEquivalent: "q"),
        ]
    }

    // MARK: - Formatters

    static func formatTime(minutes: Int?) -> String {
        guard let minutes, minutes > 0, minutes != 65535 else { return "n/a" }
        if minutes >= 60 {
            return String(format: "~%dh %02dm", minutes / 60, minutes % 60)
        }
        return String(format: "~%dm", minutes)
    }

    static func formatTemperature(_ celsius: Double?) -> String {
        guard let celsius else { return "N/A" }
        return String(format: "%.1f °C", celsius)
    }

    // MARK: - Row bodies

    private static func healthLine(_ s: BatterySnapshot) -> String {
        guard let health = s.healthPercent else { return "N/A" }
        return "\(Int(health.rounded()))% · \(Thresholds.healthLabel(health))"
    }

    private static func cyclesLine(_ s: BatterySnapshot) -> String {
        guard let cycles = s.cycleCount,
              let design = s.designCycleCount, design > 0
        else { return "N/A" }
        let used = Int((Double(cycles) / Double(design) * 100).rounded())
        return "\(cycles) of \(design) (\(used)% used)"
    }

    private static func capacityLine(_ s: BatterySnapshot) -> String {
        guard let full = s.fullChargeCapacityMAH,
              let design = s.designCapacityMAH, design > 0
        else { return "N/A" }
        let percent = Int((Double(full) / Double(design) * 100).rounded())
        return "\(full) / \(design) mAh (\(percent)%)"
    }

    private static func chargeLine(_ s: BatterySnapshot) -> String {
        guard let percent = s.chargePercent else { return "N/A" }
        if s.isCharging == true {
            return "\(percent)% · Charging"
        }
        return "\(percent)% · Discharging · \(formatTime(minutes: s.timeRemainingMinutes)) left"
    }

    private static func powerLine(_ s: BatterySnapshot) -> String {
        let voltage = s.voltageV.map { String(format: "%.1f V", $0) } ?? "N/A"
        let current = s.currentA.map { String(format: "%.2f A", $0) } ?? "N/A"
        return "\(voltage) · \(current)"
    }

    private static func lifetimeLine(_ s: BatterySnapshot) -> String {
        func temp(_ value: Double?) -> String {
            value.map { String(format: "%.1f°C", $0) } ?? "N/A°C"
        }
        return "Avg \(temp(s.lifetimeAvgTempC)) · Max \(temp(s.lifetimeMaxTempC)) · Min \(temp(s.lifetimeMinTempC))"
    }
}
