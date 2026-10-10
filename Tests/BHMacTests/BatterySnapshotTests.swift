import Foundation
@testable import BHMac

enum BatterySnapshotTests {
    static func run() {
        MiniTest.suite("BatterySnapshotTests")

        /// Fixture = real `ioreg -l -r -c AppleSmartBattery` values from the
        /// target machine (spec §3), trimmed to the keys the app reads.
        let fixture: [String: Any] = [
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

        MiniTest.test("testParseRealFixture") {
            let s = BatterySnapshot.parse(from: fixture)
            expectEqual(s.temperatureC, 34.59)
            expectEqual(s.virtualTemperatureC, 34.59)
            expectClose(s.healthPercent, 80.1, accuracy: 0.05)
            expectEqual(s.designCapacityMAH, 4382)
            expectEqual(s.fullChargeCapacityMAH, 3511)
            expectEqual(s.chargePercent, 81)
            expectEqual(s.cycleCount, 308)
            expectEqual(s.designCycleCount, 1000)
            expectClose(s.voltageV, 12.025, accuracy: 0.001)
            expectClose(s.currentA, -0.259, accuracy: 0.001)
            expectEqual(s.isCharging, false)
            expectEqual(s.timeRemainingMinutes, 577)
            expectEqual(s.lifetimeAvgTempC, 27.3)
            expectEqual(s.lifetimeMaxTempC, 46.1)
            expectEqual(s.lifetimeMinTempC, 5.8)
            expectEqual(s.temperatureSamples, 533108)
        }

        MiniTest.test("testAmperageUnsignedWraparound") {
            let s = BatterySnapshot.parse(from: ["Amperage": UInt64(18446744073709551357)])
            expectClose(s.currentA, -0.259, accuracy: 0.001)
        }

        MiniTest.test("testEmptyDictionaryYieldsAllNil") {
            let s = BatterySnapshot.parse(from: [:])
            expectEqual(s.temperatureC, nil)
            expectEqual(s.virtualTemperatureC, nil)
            expectEqual(s.healthPercent, nil)
            expectEqual(s.chargePercent, nil)
            expectEqual(s.cycleCount, nil)
            expectEqual(s.voltageV, nil)
            expectEqual(s.currentA, nil)
            expectEqual(s.isCharging, nil)
            expectEqual(s.timeRemainingMinutes, nil)
        }

        MiniTest.test("testMissingBatteryDataLeavesOptionalsNil") {
            let s = BatterySnapshot.parse(from: ["CycleCount": 308, "Voltage": 12025])
            expectEqual(s.temperatureC, nil)
            expectEqual(s.healthPercent, nil)
            expectEqual(s.cycleCount, 308)
            expectClose(s.voltageV, 12.025, accuracy: 0.001)
        }

        MiniTest.test("testFallsBackToAmperageWhenInstantMissing") {
            // InstantAmperage present -> must win over Amperage.
            let s = BatterySnapshot.parse(from: [
                "InstantAmperage": UInt64(18446744073709551357),
                "Amperage": UInt64(1234),
            ])
            expectClose(s.currentA, -0.259, accuracy: 0.001)
        }
    }
}
