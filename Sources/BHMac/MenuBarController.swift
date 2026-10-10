import AppKit

/// Thin AppKit layer: owns the NSStatusItem and renders `[MenuRow]`
/// descriptions produced by `MenuContentFactory`. No business logic here —
/// everything it displays comes from pure, tested modules.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// Called when the menu opens or Refresh is clicked — the AppDelegate
    /// responds by re-reading the battery and calling present(_:) again.
    var onMenuWillOpen: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private let menu = NSMenu()

    override init() {
        super.init()
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateTitle(_ title: MenuContentFactory.StatusTitle) {
        statusItem.button?.attributedTitle = NSAttributedString(
            string: title.text,
            attributes: [.foregroundColor: StatusStyle.color(for: title.tier)]
        )
    }

    func present(_ rows: [MenuRow]) {
        menu.removeAllItems()
        for row in rows {
            switch row {
            case .info(let text):
                let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            case .separator:
                menu.addItem(.separator())
            case .action(let title, let keyEquivalent):
                let item = NSMenuItem(
                    title: title,
                    action: #selector(handleAction(_:)),
                    keyEquivalent: keyEquivalent
                )
                item.target = self
                menu.addItem(item)
            }
        }
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
