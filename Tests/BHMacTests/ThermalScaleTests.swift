import Foundation
@testable import BHMac

/// The ruler under the temperature row is geometry, so it is tested as
/// numbers: what the domain is, where a reading lands, where the two threshold
/// ticks sit, and which stretch of track a tier owns.
enum ThermalScaleTests {
    static func run() {
        MiniTest.suite("ThermalScaleTests")

        MiniTest.test("testDomainEnds") {
            expectClose(ThermalScale.fraction(20), 0, accuracy: 0.0001)
            expectClose(ThermalScale.fraction(50), 1, accuracy: 0.0001)
            expectClose(ThermalScale.fraction(35), 0.5, accuracy: 0.0001)
        }

        MiniTest.test("testReadingsOutsideDomainClamp") {
            // A freezing or roasting battery still shows a needle, never a
            // reading that fell off the track.
            expectClose(ThermalScale.fraction(-10), 0, accuracy: 0.0001)
            expectClose(ThermalScale.fraction(5), 0, accuracy: 0.0001)
            expectClose(ThermalScale.fraction(90), 1, accuracy: 0.0001)
        }

        MiniTest.test("testTicksMarkTheSpecThresholds") {
            let ticks = ThermalScale.ticks
            expectEqual(ticks.count, 2)
            expectEqual(ticks[0].value, 35)
            expectEqual(ticks[0].label, "35°")
            expectEqual(ticks[1].value, 42)
            expectEqual(ticks[1].label, "42°")
            // Warm's boundary sits left of Hot's, and both inside the track.
            MiniTest.expect(ticks[0].fraction < ticks[1].fraction)
            MiniTest.expect(ticks[0].fraction >= 0 && ticks[1].fraction <= 1)
        }

        MiniTest.test("testBandsTileTheTrackWithoutGaps") {
            let normal = ThermalScale.band(.normal)
            let warm = ThermalScale.band(.warm)
            let hot = ThermalScale.band(.hot)
            expectClose(normal.lowerBound, 0, accuracy: 0.0001)
            expectClose(normal.upperBound, warm.lowerBound, accuracy: 0.0001)
            expectClose(warm.upperBound, hot.lowerBound, accuracy: 0.0001)
            expectClose(hot.upperBound, 1, accuracy: 0.0001)
            // Warm owns a visible stretch of its own, not a sliver.
            MiniTest.expect(warm.upperBound - warm.lowerBound > 0.1)
        }

        MiniTest.test("testMutedTierLightsNothing") {
            let band = ThermalScale.band(.muted)
            expectClose(band.upperBound - band.lowerBound, 0, accuracy: 0.0001)
            expectClose(band.lowerBound, ThermalScale.fraction(ThermalScale.domainHigh), accuracy: 0.0001)
        }

        MiniTest.test("testReadingDerivesItsTier") {
            expectEqual(ThermalReading(temperatureC: nil).tier, .muted)
            expectEqual(ThermalReading(temperatureC: nil).temperatureC, nil)
            expectEqual(ThermalReading(temperatureC: 34.9).tier, .normal)
            expectEqual(ThermalReading(temperatureC: 36.0).tier, .warm)
            expectEqual(ThermalReading(temperatureC: 50.0).tier, .hot)
            expectEqual(ThermalReading(temperatureC: 34.9, tier: .hot).tier, .hot)
        }
    }
}
