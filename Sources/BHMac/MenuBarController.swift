import AppKit

/// Thin AppKit layer: owns the NSStatusItem and renders `[MenuRow]` as the
/// instrument faceplate (`MenuMetricRowView`, `MenuSectionRowView`,
/// `ThermalScaleRowView`). No business logic here — everything it displays
/// comes from pure, tested modules.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// Called when the menu opens or Refresh is clicked — the AppDelegate
    /// responds by re-reading the battery and calling present(_:) again.
    var onMenuWillOpen: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private let menu = NSMenu()
    private(set) var currentTitle: MenuContentFactory.StatusTitle?

    override init() {
        super.init()
        menu.delegate = self
        menu.font = MenuMetrics.actionFont()
        statusItem.menu = menu
        statusItem.button?.setAccessibilityLabel("Battery Health")
    }

    /// The status item: one neutral glyph plus the reading in tabular
    /// figures, so a digit change never reflows the menu bar. The tier color
    /// is not spent here — it lives in the dropdown (spec §6).
    /// Skips updating if the title has not changed to avoid redundant WindowServer redraws.
    func updateTitle(_ title: MenuContentFactory.StatusTitle) {
        if currentTitle == title {
            return
        }
        currentTitle = title

        statusItem.button?.attributedTitle = NSAttributedString(
            string: title.text,
            attributes: [
                .foregroundColor: StatusStyle.statusItemColor,
                .font: MenuMetrics.titleFont(),
            ]
        )
        if let symbolName = title.symbolName {
            statusItem.button?.image = StatusStyle.statusSymbol(
                named: symbolName, pointSize: 11
            )
            statusItem.button?.imagePosition = .imageLeading
        } else {
            statusItem.button?.image = nil
        }
        statusItem.button?.setAccessibilityValue(title.accessibilityValue)
    }

    func present(_ rows: [MenuRow]) {
        menu.removeAllItems()
        for row in rows {
            switch row {
            case .section(let title):
                menu.addItem(disabledItem(with: MenuSectionRowView(title: title)))
            case .metric(let label, let value):
                menu.addItem(disabledItem(with: MenuMetricRowView(label: label, value: value)))
            case .scale(let reading):
                menu.addItem(disabledItem(with: ThermalScaleRowView(reading: reading)))
            case .message(let text):
                menu.addItem(disabledItem(with: MenuMessageRowView(text)))
            case .action(let title, let keyEquivalent):
                let item = NSMenuItem(
                    title: title,
                    action: #selector(handleAction(_:)),
                    keyEquivalent: keyEquivalent
                )
                item.target = self
                menu.addItem(item)
            case .separator:
                menu.addItem(.separator())
            }
        }
    }

    private func disabledItem(with view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        item.isEnabled = false
        return item
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        onMenuWillOpen?()
    }

    // MARK: - Actions

    @objc private func handleAction(_ sender: NSMenuItem) {
        switch sender.title {
        case "Refresh":
            onMenuWillOpen?()
        case "Quit":
            NSApp.terminate(nil)
        default:
            break
        }
    }
}
