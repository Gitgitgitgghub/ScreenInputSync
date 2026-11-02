import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem
    private let modeMenuItem: NSMenuItem
    private let loginMenuItem: NSMenuItem
    private let loginStatusMenuItem: NSMenuItem
    var onResync: (() -> Void)?
    var onLaunchAtLoginSelected: (() -> Void)?
    var onMenuWillOpen: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        modeMenuItem = NSMenuItem(title: "Input: Unknown", action: nil, keyEquivalent: "")
        loginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
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
        loginStatusMenuItem.isEnabled = false
        loginStatusMenuItem.isHidden = true
        menu.addItem(loginStatusMenuItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit \(AppMetadata.displayName)",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateStatus(_ text: String) {
        statusMenuItem.title = text
    }

    func updateMode(_ mode: InputMode) {
        modeMenuItem.title = mode == .english ? "Input: ABC" : "Input: 注音"
    }

    func setLaunchAtLoginStatus(_ status: LoginItemStatus) {
        switch status {
        case .enabled:
            loginMenuItem.state = .on
        case .requiresApproval:
            loginMenuItem.state = .mixed
        case .notRegistered, .notFound:
            loginMenuItem.state = .off
        }
    }

    func updateLoginStatus(_ text: String?) {
        loginStatusMenuItem.title = text ?? ""
        loginStatusMenuItem.isHidden = text == nil
    }

    @objc private func showResync() {
        onResync?()
    }

    @objc private func toggleLoginItem() {
        onLaunchAtLoginSelected?()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        onMenuWillOpen?()
    }
}
