import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem
    private let loginMenuItem: NSMenuItem
    private let loginStatusMenuItem: NSMenuItem
    var onResync: (() -> Void)?
    var onLaunchAtLoginSelected: (() -> Void)?
    var onMenuWillOpen: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = NSMenuItem(title: "啟動中…", action: nil, keyEquivalent: "")
        loginMenuItem = NSMenuItem(title: "登入時啟動", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: AppMetadata.displayName
        )

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        let resyncItem = menu.addItem(
            withTitle: "對齊遠端輸入法",
            action: #selector(showResync),
            keyEquivalent: ""
        )
        resyncItem.target = self
        resyncItem.attributedTitle = Self.titleWithHint("對齊遠端輸入法", hint: "⌘⇧")
        resyncItem.toolTip = "僅限螢幕共享位於前景時使用。快捷鍵：在螢幕共享中同時按下 ⌘ 和 ⇧ 再放開（中間不要按其他鍵）"
        loginMenuItem.target = self
        menu.addItem(loginMenuItem)
        loginStatusMenuItem.isEnabled = false
        loginStatusMenuItem.isHidden = true
        menu.addItem(loginStatusMenuItem)
        menu.addItem(
            withTitle: "開啟輔助使用權限設定",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        let versionItem = NSMenuItem(title: "版本 \(AppMetadata.version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(
            withTitle: "結束 \(AppMetadata.displayName)",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateStatus(_ text: String) {
        statusMenuItem.title = text
    }

    /// Appends the resync gesture right after the title. The gesture
    /// (Command + Shift released alone) cannot be a real key equivalent.
    private static func titleWithHint(_ title: String, hint: String) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let result = NSMutableAttributedString(string: title, attributes: [.font: font])
        result.append(NSAttributedString(
            string: "  " + hint,
            attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        ))
        return result
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

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
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
