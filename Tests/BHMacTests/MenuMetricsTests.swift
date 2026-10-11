import AppKit
@testable import BHMac

enum MenuMetricsTests {
    static func run() {
        MiniTest.suite("MenuMetricsTests")

        MiniTest.test("testTitleFontIsNeutralElevenTabular") {
            // MenuMetrics is @MainActor; this executable's main runs on the
            // main thread, so assumeIsolated is exact, not a hope.
            MainActor.assumeIsolated {
                let font = MenuMetrics.titleFont()
                expectEqual(font.pointSize, 11.0)
                // Tabular digits so the menu-bar item never jitters as the
                // reading changes.
                expectEqual(font, NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular))
            }
        }
    }
}
