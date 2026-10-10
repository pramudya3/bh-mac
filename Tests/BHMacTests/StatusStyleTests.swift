import AppKit
@testable import BHMac

enum StatusStyleTests {
    static func run() {
        MiniTest.suite("StatusStyleTests")

        MiniTest.test("testTierColors") {
            expectEqual(StatusStyle.color(for: .muted), NSColor.secondaryLabelColor)
            expectEqual(StatusStyle.color(for: .normal), NSColor.systemGreen)
            expectEqual(StatusStyle.color(for: .warm), NSColor.systemOrange)
            expectEqual(StatusStyle.color(for: .hot), NSColor.systemRed)
        }
    }
}
