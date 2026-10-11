import Foundation

/// How the words in the value column are colored. The instrument keeps one
/// accent — the tier palette — and spends it only where state is being
/// reported; every other word stays a system neutral.
enum MenuSignal: Equatable {
    /// No state to report: plain secondary text.
    case neutral
    /// The live temperature's tier (temperature row, thermal scale).
    case thermal(TempTier)
    /// The battery's health band (the health row).
    case health(HealthCondition)
}

/// One value in the menu's value column: the measured number in the
/// measurement face, plus, when the register carries a state word with it,
/// that word in the human face.
struct MenuValue: Equatable {
    /// The reading itself, e.g. `80%`, `3511 / 4382 mAh`, `~9h 37m`.
    let measurement: String
    /// The state or qualifier that rides with it, e.g. `Normal`,
    /// `(31% used)`. `nil` when the reading speaks for itself.
    let note: String?
    let signal: MenuSignal

    init(measurement: String, note: String? = nil, signal: MenuSignal = .neutral) {
        self.measurement = measurement
        self.note = note
        self.signal = signal
    }

    /// No reading for this register. Rendered muted, never as a number we
    /// would have had to invent.
    static func unavailable(signal: MenuSignal = .neutral) -> MenuValue {
        MenuValue(measurement: unavailableText, signal: signal)
    }

    static let unavailableText = "N/A"
    static let timeUnavailableText = "n/a"

    var isUnavailable: Bool {
        measurement == MenuValue.unavailableText || measurement == MenuValue.timeUnavailableText
    }
}

/// A live temperature as the thermal scale reads it.
struct ThermalReading: Equatable {
    /// Degrees Celsius, or `nil` when no reading exists — the ruler then draws
    /// its scale and no needle.
    let temperatureC: Double?
    /// The tier the reading falls in; `.muted` when there is no reading.
    let tier: TempTier

    init(temperatureC: Double?, tier: TempTier) {
        self.temperatureC = temperatureC
        self.tier = tier
    }

    init(temperatureC: Double?) {
        guard let temperatureC else {
            self.init(temperatureC: nil, tier: .muted)
            return
        }
        self.init(temperatureC: temperatureC, tier: Thresholds.temperatureTier(temperatureC))
    }

    static let noReading = ThermalReading(temperatureC: nil, tier: .muted)
}

/// One row of the status menu, as data. `MenuBarController` is the AppKit
/// layer that renders these; everything here is pure so every display
/// decision is unit-tested (spec §6).
enum MenuRow: Equatable {
    /// A section head: uppercase, tracked, quiet. Groups the registers below it.
    case section(String)
    /// A labelled register: label on the left column, value on the right edge.
    case metric(label: String, value: MenuValue)
    /// The thermal ruler under the temperature row.
    case scale(ThermalReading)
    /// A plain disabled line — the no-battery case.
    case message(String)
    /// A clickable row with its key equivalent.
    case action(String, keyEquivalent: String)
    case separator
}
