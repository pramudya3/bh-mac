import Foundation

/// One battery reading, every field optional: the registry may not carry
/// every key (and a desktop Mac carries none). Parsing is pure — the IOKit
/// seam lives in `IOKitBatteryReader` and hands this a real dictionary.
///
/// Units, per spec §5:
/// - `temperatureC` / `virtualTemperatureC`: degrees Celsius (registry stores
///   centi-degrees; we divide by 100 at parse time)
/// - `lifetime*TempC`: degrees Celsius from `LifetimeData`, which uses
///   deci-degrees (divide by 10)
/// - `voltageV`: volts (registry millivolts)
/// - `currentA`: amps, negative = discharging (registry milliamps stored as
///   two's-complement 64-bit — see the amperage decode below)
/// - `timeRemainingMinutes` / `avgTimeToEmptyMinutes`: minutes
/// - capacities: mAh; `chargePercent`, `healthPercent`, `cycleCount`: counts
struct BatterySnapshot {
    let temperatureC: Double?
    let virtualTemperatureC: Double?
    let healthPercent: Double?
    let designCapacityMAH: Int?
    let fullChargeCapacityMAH: Int?
    let chargePercent: Int?
    let cycleCount: Int?
    let designCycleCount: Int?
    let voltageV: Double?
    let currentA: Double?
    let isCharging: Bool?
    let timeRemainingMinutes: Int?
    let avgTimeToEmptyMinutes: Int?
    let lifetimeAvgTempC: Double?
    let lifetimeMaxTempC: Double?
    let lifetimeMinTempC: Double?
    let temperatureSamples: Int?

    static func parse(from properties: [String: Any]) -> BatterySnapshot {
        let batteryData = properties["BatteryData"] as? [String: Any]
        let lifetimeData = batteryData?["LifetimeData"] as? [String: Any]

        let designCapacity = intValue(batteryData?["DesignCapacity"])
        let fullChargeCapacity = intValue(batteryData?["FullChargeCapacity"])
        let healthPercent: Double? = {
            guard let design = designCapacity, design > 0,
                  let full = fullChargeCapacity
            else { return nil }
            return Double(full) / Double(design) * 100
        }()

        return BatterySnapshot(
            temperatureC: centiCToC(intValue(batteryData?["Temperature"])),
            virtualTemperatureC: centiCToC(intValue(batteryData?["VirtualTemperature"])),
            healthPercent: healthPercent,
            designCapacityMAH: designCapacity,
            fullChargeCapacityMAH: fullChargeCapacity,
            chargePercent: intValue(properties["CurrentCapacity"]),
            cycleCount: intValue(properties["CycleCount"]),
            designCycleCount: intValue(properties["DesignCycleCount9C"]),
            voltageV: milliToBase(intValue(properties["Voltage"])),
            currentA: decodeCurrentAmps(properties),
            isCharging: boolValue(properties["IsCharging"]),
            timeRemainingMinutes: intValue(properties["TimeRemaining"]),
            avgTimeToEmptyMinutes: intValue(properties["AvgTimeToEmpty"]),
            lifetimeAvgTempC: deciCToC(intValue(lifetimeData?["AverageTemperature"])),
            lifetimeMaxTempC: deciCToC(intValue(lifetimeData?["MaximumTemperature"])),
            lifetimeMinTempC: deciCToC(intValue(lifetimeData?["MinimumTemperature"])),
            temperatureSamples: intValue(lifetimeData?["TemperatureSamples"])
        )
    }
}

private func intValue(_ value: Any?) -> Int? {
    guard let value else { return nil }
    if let i = value as? Int { return i }
    if let u = value as? UInt64 { return Int(exactly: u) }
    if let s = value as? Int64 { return Int(exactly: s) }
    return nil
}

private func boolValue(_ value: Any?) -> Bool? {
    guard let value else { return nil }
    if let b = value as? Bool { return b }
    if let i = value as? Int { return i == 1 }
    return nil
}

private func centiCToC(_ centi: Int?) -> Double? {
    centi.map { Double($0) / 100.0 }
}

/// LifetimeData temperatures use 0.1 °C resolution (unlike the live
/// `Temperature` key, which is centi-degrees): 273 -> 27.3 °C.
private func deciCToC(_ deci: Int?) -> Double? {
    deci.map { Double($0) / 10.0 }
}

private func milliToBase(_ milli: Int?) -> Double? {
    milli.map { Double($0) / 1000.0 }
}

/// The registry stores amperage as a 64-bit two's-complement number printed
/// unsigned (e.g. 18446744073709551357 = -259). Prefer `InstantAmperage`,
/// fall back to `Amperage`. Returns amps (registry is milliamps).
private func decodeCurrentAmps(_ properties: [String: Any]) -> Double? {
    for key in ["InstantAmperage", "Amperage"] {
        guard let raw = properties[key] else { continue }
        var milliamps: Double? = nil
        if let u = raw as? UInt64 {
            milliamps = Double(Int64(bitPattern: u))
        } else if let s = raw as? Int64 {
            milliamps = Double(s)
        } else if let i = raw as? Int {
            milliamps = Double(i)
        }
        if let milliamps { return milliamps / 1000.0 }
    }
    return nil
}
