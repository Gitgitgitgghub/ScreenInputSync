import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: AppMetadata.displayName
        )

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit \(AppMetadata.displayName)",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self
        statusItem.menu = menu
    }

    func updateStatus(_ text: String) {
        statusMenuItem.title = text
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
