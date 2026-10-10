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

enum MenuContentFactoryTests {
    static func run() {
        MiniTest.suite("MenuContentFactoryTests")

        let snapshot = BatterySnapshot.parse(from: realMachineFixture())

        MiniTest.test("testFullSnapshotRows") {
            expectEqual(MenuContentFactory.makeRows(from: snapshot), [
                .info("Battery Health — 80% · Normal"),
                .info("Temperature — 34.6 °C"),
                .info("Cycles — 308 of 1000 (31% used)"),
                .info("Capacity — 3511 / 4382 mAh (80%)"),
                .info("Charge — 81% · Discharging · ~9h 37m left"),
                .info("Power — 12.0 V · -0.26 A"),
                .info("Lifetime (recorded) — Avg 27.3°C · Max 46.1°C · Min 5.8°C"),
                .separator,
                .action("Refresh", keyEquivalent: "r"),
                .separator,
                .action("Quit", keyEquivalent: "q"),
            ])
            let title = MenuContentFactory.makeTitle(from: snapshot)
            expectEqual(title.text, "34.6°C")
            expectEqual(title.tier, .normal)
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
            let rows = MenuContentFactory.makeRows(from: partial)
            expectEqual(rows[1], .info("Temperature — N/A"))
            // Every other row stays intact.
            expectEqual(rows[0], .info("Battery Health — 80% · Normal"))
            expectEqual(rows[2], .info("Cycles — 308 of 1000 (31% used)"))
            expectEqual(rows[6], .info("Lifetime (recorded) — Avg 27.3°C · Max 46.1°C · Min 5.8°C"))
            expectEqual(rows[10], .action("Quit", keyEquivalent: "q"))
        }

        MiniTest.test("testNilSnapshotReturnsNoBattery") {
            let title = MenuContentFactory.makeTitle(from: nil)
            expectEqual(title.text, "No Battery")
            expectEqual(title.tier, .muted)
            expectEqual(MenuContentFactory.makeRows(from: nil), [.info("No battery detected")])
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
            expectEqual(
                MenuContentFactory.makeRows(from: unknown)[4],
                .info("Charge — 81% · Unknown")
            )
        }

        MiniTest.test("testChargingRowOmitsTimeLeft") {
            var dict = realMachineFixture()
            dict["IsCharging"] = true
            let charging = BatterySnapshot.parse(from: dict)
            expectEqual(
                MenuContentFactory.makeRows(from: charging)[4],
                .info("Charge — 81% · Charging")
            )
        }
    }
}
