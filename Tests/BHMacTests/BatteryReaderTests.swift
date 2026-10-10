import Foundation
@testable import BHMac

enum BatteryReaderTests {
    static func run() {
        MiniTest.suite("BatteryReaderTests")

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
