import Foundation
@testable import BHMac

enum BatteryReaderTests {
    static func run() {
        MiniTest.suite("BatteryReaderTests")

        MiniTest.test("testMergeSemanticsServiceOnly") {
            let merged = IOKitBatteryReader.mergedProperties(
                service: ["CycleCount": 308, "BatteryData": ["FullChargeCapacity": 3511]],
                pack: nil
            )
            let s = BatterySnapshot.parse(from: merged)
            expectEqual(s.cycleCount, 308)
            expectEqual(s.temperatureC, nil)
            expectEqual(s.fullChargeCapacityMAH, 3511)
        }

        MiniTest.test("testMergeSemanticsPackWins") {
            let merged = IOKitBatteryReader.mergedProperties(
                service: ["CycleCount": 308, "BatteryData": ["FullChargeCapacity": 3511, "Temperature": 9999]],
                pack: ["BatteryData": ["Temperature": 3459, "DesignCapacity": 4382]]
            )
            let s = BatterySnapshot.parse(from: merged)
            // pack's Temperature (3459) must win over service's (9999)
            expectEqual(s.temperatureC, 34.59)
            expectClose(s.healthPercent, 80.1, accuracy: 0.05)
            expectEqual(s.cycleCount, 308)
        }

        MiniTest.test("testMergeSemanticsReadFailureIsEmpty") {
            // Both reads failed (services exist, properties nil): merged is
            // empty -> parse yields an all-nil snapshot, NOT "No Battery".
            let merged = IOKitBatteryReader.mergedProperties(service: nil, pack: nil)
            expectEqual(merged.isEmpty, true)
            let s = BatterySnapshot.parse(from: merged)
            expectEqual(s.temperatureC, nil)
        }

        // Live-machine test: cannot run on a desktop Mac, so skip there
        // instead of failing.
        MiniTest.test("testReadSnapshotFromLiveMachine") {
            let snapshot = IOKitBatteryReader().readSnapshot()
            guard let snapshot else {
                MiniTest.skip("No AppleSmartBattery service (desktop Mac)")
                return
            }
            MiniTest.expect(snapshot.temperatureC != nil, "temperatureC should be present on a notebook")
            MiniTest.expect(snapshot.cycleCount != nil, "cycleCount should be present on a notebook")
        }
    }
}
