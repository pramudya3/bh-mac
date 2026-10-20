import AppKit
@testable import BHMac

@MainActor
enum MenuBarControllerTests {
    static func run() {
        MiniTest.suite("MenuBarControllerTests")

        MiniTest.test("testUpdateTitleDeduplication") {
            let controller = MenuBarController()
            let title1 = MenuContentFactory.StatusTitle(text: "34.0°C", tier: .normal, symbolName: "thermometer.medium")
            let title2 = MenuContentFactory.StatusTitle(text: "34.0°C", tier: .normal, symbolName: "thermometer.medium")
            let title3 = MenuContentFactory.StatusTitle(text: "35.0°C", tier: .warm, symbolName: "thermometer.medium")

            controller.updateTitle(title1)
            expectEqual(controller.currentTitle, title1)

            controller.updateTitle(title2)
            expectEqual(controller.currentTitle, title1)

            controller.updateTitle(title3)
            expectEqual(controller.currentTitle, title3)
        }
    }
}
