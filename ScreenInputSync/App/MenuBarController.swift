import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem
    private let modeMenuItem: NSMenuItem
    private let loginMenuItem: NSMenuItem
    var onResync: (() -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        modeMenuItem = NSMenuItem(title: "Input: Unknown", action: nil, keyEquivalent: "")
        loginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: AppMetadata.displayName
        )

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        modeMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(modeMenuItem)
        menu.addItem(.separator())
        let resyncItem = menu.addItem(
            withTitle: "Resync with Remote…",
            action: #selector(showResync),
            keyEquivalent: ""
        )
        resyncItem.target = self
        loginMenuItem.target = self
        menu.addItem(loginMenuItem)
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

    func updateMode(_ mode: InputMode) {
        modeMenuItem.title = mode == .english ? "Input: ABC" : "Input: 注音"
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginMenuItem.state = enabled ? .on : .off
    }

    @objc private func showResync() {
        onResync?()
    }

    @objc private func toggleLoginItem() {
        let enabled = loginMenuItem.state != .on
        setLaunchAtLogin(enabled)
        onLaunchAtLoginChanged?(enabled)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
