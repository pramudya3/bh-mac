import AppKit

/// App lifecycle: wires the IOKit reader to the menu bar on a fixed cadence,
/// and refreshes on demand whenever the menu opens or Refresh is clicked.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let reader: BatteryReading
    private let controller = MenuBarController()
    private var timer: Timer?

    init(reader: BatteryReading = IOKitBatteryReader()) {
        self.reader = reader
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.onMenuWillOpen = { [weak self] in
            self?.refreshMenu()
        }
        refreshMenu()
        let scheduledTimer = Timer.scheduledTimer(
            timeInterval: Thresholds.pollInterval,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
        // Allow macOS power management to coalesce wakeups to preserve CPU idle states.
        scheduledTimer.tolerance = 2.0
        timer = scheduledTimer
    }

    @objc private func timerFired() {
        refreshStatusItem()
    }

    /// Background cadence: updates only the status bar button.
    /// Does not rebuild dropdown menu views while the menu is closed.
    private func refreshStatusItem() {
        let snapshot = reader.readSnapshot()
        controller.updateTitle(MenuContentFactory.makeTitle(from: snapshot))
    }

    /// On-demand: updates title and builds full dropdown menu rows when opening or refreshing.
    private func refreshMenu() {
        let snapshot = reader.readSnapshot()
        controller.updateTitle(MenuContentFactory.makeTitle(from: snapshot))
        controller.present(MenuContentFactory.makeRows(from: snapshot))
    }
}

/// Application bootstrap. Everything above this line is internal glue; only
/// this entry point is public so the thin `BHMacApp` main can start the app.
@MainActor
public func runBHMacApp() {
    let app = NSApplication.shared
    // LSUIElement=true in the bundle keeps the app out of the Dock; the
    // accessory policy covers running the binary directly (swift run).
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    // app.delegate is weak — keep the strong reference alive for the run loop.
    app.delegate = delegate
    app.run()
}
