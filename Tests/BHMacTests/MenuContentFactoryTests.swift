import Foundation
@testable import BHMac

func realMachineFixture() -> [String: Any] {
    [
        "CycleCount": 308,
        "DesignCycleCount9C": 1000,
        "Voltage": 12025,
        "InstantAmperage": UInt64(18446744073709551357),
        "CurrentCapacity": 81,
        "IsCharging": false,
        "TimeRemaining": 577,
        "AvgTimeToEmpty": 577,
        "BatteryData": [
            "Temperature": 3459,
            "VirtualTemperature": 3459,
            "DesignCapacity": 4382,
            "FullChargeCapacity": 3511,
            "LifetimeData": [
                "AverageTemperature": 273,
                "MaximumTemperature": 461,
                "MinimumTemperature": 58,
                "TemperatureSamples": 533108,
            ],
        ],
    ]
}

/// The dropdown is a fixed register order; fetch a value by its label instead
/// of by index, so presentation can move rows without breaking the facts.
func metricValue(_ rows: [MenuRow], label: String) -> MenuValue? {
    for row in rows {
        if case .metric(let rowLabel, let value) = row, rowLabel == label { return value }
    }
    return nil
}

func rowLabels(_ rows: [MenuRow]) -> [String] {
    rows.compactMap { row in
        if case .metric(let label, _) = row { return label }
        if case .section(let title) = row { return "§\(title)" }
        return nil
    }
}

enum MenuContentFactoryTests {
    static func run() {
        MiniTest.suite("MenuContentFactoryTests")

        let snapshot = BatterySnapshot.parse(from: realMachineFixture())

        MiniTest.test("testFullSnapshotRows") {
            expectEqual(MenuContentFactory.makeRows(from: snapshot), [
                .section(MenuContentFactory.conditionSection),
                .metric(
                    label: "Battery Health",
                    value: MenuValue(measurement: "80%", note: "Normal", signal: .health(.normal))
                ),
                .metric(
                    label: "Temperature",
                    value: MenuValue(measurement: "34.6 °C", signal: .thermal(.normal))
                ),
                .scale(ThermalReading(temperatureC: 34.59, tier: .normal)),
                .metric(label: "Cycles", value: MenuValue(measurement: "308 of 1000", note: "(31% used)")),
                .metric(label: "Capacity", value: MenuValue(measurement: "3511 / 4382 mAh", note: "(80%)")),
                .separator,
                .section(MenuContentFactory.nowSection),
                .metric(label: "Charge", value: MenuValue(measurement: "81%", note: "Discharging")),
                .metric(label: "Time left", value: MenuValue(measurement: "~9h 37m")),
                .metric(label: "Power", value: MenuValue(measurement: "12.0 V · -0.26 A")),
                .separator,
                .section(MenuContentFactory.lifetimeSection),
                .metric(label: "Average", value: MenuValue(measurement: "27.3 °C")),
                .metric(label: "Maximum", value: MenuValue(measurement: "46.1 °C")),
                .metric(label: "Minimum", value: MenuValue(measurement: "5.8 °C")),
                .separator,
                .action("Refresh", keyEquivalent: "r"),
                .separator,
                .action("Quit", keyEquivalent: "q"),
            ])
            let title = MenuContentFactory.makeTitle(from: snapshot)
            expectEqual(title.text, "34.6°C")
            expectEqual(title.tier, .normal)
            expectEqual(title.symbolName, MenuContentFactory.statusSymbolName)
            expectEqual(title.accessibilityValue, "Temperature 34.6°C, normal")
        }

        MiniTest.test("testMissingTemperatureYieldsNARow") {
            var dict = realMachineFixture()
            var batteryData = dict["BatteryData"] as? [String: Any] ?? [:]
            batteryData["Temperature"] = nil
            batteryData["VirtualTemperature"] = nil
            dict["BatteryData"] = batteryData
            let partial = BatterySnapshot.parse(from: dict)
            let title = MenuContentFactory.makeTitle(from: partial)
            expectEqual(title.text, "—")
            expectEqual(title.tier, .muted)
            expectEqual(title.symbolName, nil)
            expectEqual(title.accessibilityValue, "Temperature unavailable")
            let rows = MenuContentFactory.makeRows(from: partial)
            expectEqual(
                metricValue(rows, label: "Temperature"),
                MenuValue(measurement: "N/A", signal: .thermal(.muted))
            )
            // Every other row stays intact.
            expectEqual(
                metricValue(rows, label: "Battery Health"),
                MenuValue(measurement: "80%", note: "Normal", signal: .health(.normal))
            )
            expectEqual(
                metricValue(rows, label: "Cycles"),
                MenuValue(measurement: "308 of 1000", note: "(31% used)")
            )
            expectEqual(
                metricValue(rows, label: "Maximum"),
                MenuValue(measurement: "46.1 °C")
            )
        }

        MiniTest.test("testNilSnapshotReturnsNoBattery") {
            let title = MenuContentFactory.makeTitle(from: nil)
            expectEqual(title.text, "No Battery")
            expectEqual(title.tier, .muted)
            expectEqual(title.symbolName, nil)
            expectEqual(title.accessibilityValue, "No battery detected")
            expectEqual(MenuContentFactory.makeRows(from: nil), [.message("No battery detected")])
        }

        MiniTest.test("testFormatTimeBoundaries") {
            expectEqual(MenuContentFactory.formatTime(minutes: nil), "n/a")
            expectEqual(MenuContentFactory.formatTime(minutes: 0), "n/a")
            expectEqual(MenuContentFactory.formatTime(minutes: -5), "n/a")
            expectEqual(MenuContentFactory.formatTime(minutes: 65535), "n/a")
            expectEqual(MenuContentFactory.formatTime(minutes: 37), "~37m")
            expectEqual(MenuContentFactory.formatTime(minutes: 577), "~9h 37m")
        }

        MiniTest.test("testFormatTemperature") {
            expectEqual(MenuContentFactory.formatTemperature(nil), "N/A")
            expectEqual(MenuContentFactory.formatTemperature(34.59), "34.6 °C")
        }

        MiniTest.test("testChargingStateUnknownRow") {
            var dict = realMachineFixture()
            dict.removeValue(forKey: "IsCharging")
            let unknown = BatterySnapshot.parse(from: dict)
            let rows = MenuContentFactory.makeRows(from: unknown)
            expectEqual(
                metricValue(rows, label: "Charge"),
                MenuValue(measurement: "81%", note: "Unknown")
            )
            // Unknown state gets no time-left row rather than a bogus one.
            expectEqual(metricValue(rows, label: "Time left"), nil)
        }

        MiniTest.test("testChargingRowOmitsTimeLeft") {
            var dict = realMachineFixture()
            dict["IsCharging"] = true
            let charging = BatterySnapshot.parse(from: dict)
            let rows = MenuContentFactory.makeRows(from: charging)
            expectEqual(
                metricValue(rows, label: "Charge"),
                MenuValue(measurement: "81%", note: "Charging")
            )
            expectEqual(metricValue(rows, label: "Time left"), nil)
        }

        MiniTest.test("testTimeLeftHiddenWhenRegisterCalculating") {
            var dict = realMachineFixture()
            dict["TimeRemaining"] = 65535
            dict["AvgTimeToEmpty"] = 65535
            let calculating = BatterySnapshot.parse(from: dict)
            let rows = MenuContentFactory.makeRows(from: calculating)
            expectEqual(
                metricValue(rows, label: "Charge"),
                MenuValue(measurement: "81%", note: "Discharging")
            )
            expectEqual(metricValue(rows, label: "Time left"), nil)
        }

        MiniTest.test("testFallbackTemperatureFeedsTitleAndScale") {
            var dict = realMachineFixture()
            var batteryData = dict["BatteryData"] as? [String: Any] ?? [:]
            batteryData["Temperature"] = nil
            batteryData["VirtualTemperature"] = 3901
            dict["BatteryData"] = batteryData
            let hot = BatterySnapshot.parse(from: dict)
            expectEqual(MenuContentFactory.makeTitle(from: hot).tier, .warm)
            let rows = MenuContentFactory.makeRows(from: hot)
            expectEqual(
                metricValue(rows, label: "Temperature"),
                MenuValue(measurement: "39.0 °C", signal: .thermal(.warm))
            )
            expectEqual(
                rows.first(where: { if case .scale = $0 { return true }; return false }),
                .scale(ThermalReading(temperatureC: 39.01, tier: .warm))
            )
        }

        MiniTest.test("testRegisterOrderIsStable") {
            expectEqual(rowLabels(MenuContentFactory.makeRows(from: snapshot)), [
                "§Condition",
                "Battery Health", "Temperature", "Cycles", "Capacity",
                "§Right now",
                "Charge", "Time left", "Power",
                "§Lifetime (recorded)",
                "Average", "Maximum", "Minimum",
            ])
        }

        MiniTest.test("testUnavailableValueRendersMuted") {
            MiniTest.expect(MenuValue(measurement: "N/A").isUnavailable)
            MiniTest.expect(MenuValue(measurement: "n/a").isUnavailable)
            MiniTest.expect(!MenuValue(measurement: "81%").isUnavailable)
        }

        MiniTest.test("testStatusTitleEquality") {
            let t1 = MenuContentFactory.StatusTitle(text: "34.5°C", tier: .normal, symbolName: "thermometer.medium")
            let t2 = MenuContentFactory.StatusTitle(text: "34.5°C", tier: .normal, symbolName: "thermometer.medium")
            let t3 = MenuContentFactory.StatusTitle(text: "35.0°C", tier: .normal, symbolName: "thermometer.medium")
            MiniTest.expect(t1 == t2)
            MiniTest.expect(t1 != t3)
        }
    }
}
