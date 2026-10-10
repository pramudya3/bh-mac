@testable import BHMac

enum ThresholdsTests {
    static func run() {
        MiniTest.suite("ThresholdsTests")

        MiniTest.test("testTemperatureTierBoundaries") {
            expectEqual(Thresholds.temperatureTier(34.9), .normal)
            expectEqual(Thresholds.temperatureTier(35.0), .normal)
            expectEqual(Thresholds.temperatureTier(35.1), .warm)
            expectEqual(Thresholds.temperatureTier(42.0), .warm)
            expectEqual(Thresholds.temperatureTier(42.1), .hot)
        }

        MiniTest.test("testHealthLabels") {
            expectEqual(Thresholds.healthLabel(92.0), "Normal")
            expectEqual(Thresholds.healthLabel(80.0), "Normal")
            expectEqual(Thresholds.healthLabel(79.9), "Replace Soon")
            expectEqual(Thresholds.healthLabel(60.0), "Replace Soon")
            expectEqual(Thresholds.healthLabel(59.9), "Service")
        }
    }
}
