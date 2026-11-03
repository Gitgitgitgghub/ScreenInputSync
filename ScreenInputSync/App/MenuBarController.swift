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
        statusMenuItem = NSMenuItem(title: "啟動中…", action: nil, keyEquivalent: "")
        modeMenuItem = NSMenuItem(title: "本機：—　遠端：—", action: nil, keyEquivalent: "")
        loginMenuItem = NSMenuItem(title: "登入時啟動", action: #selector(toggleLoginItem), keyEquivalent: "")
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
            withTitle: "對齊遠端輸入法…",
            action: #selector(showResync),
            keyEquivalent: ""
        )
        resyncItem.target = self
        resyncItem.attributedTitle = Self.titleWithHint("對齊遠端輸入法…", hint: "⌘ → ⇧")
        resyncItem.toolTip = "在螢幕共享中：先按住 ⌘，再按住 ⇧，然後兩鍵都放開"
        loginMenuItem.target = self
        menu.addItem(loginMenuItem)
        loginStatusMenuItem.isEnabled = false
        loginStatusMenuItem.isHidden = true
        menu.addItem(loginStatusMenuItem)
        menu.addItem(.separator())
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

    func updateMode(local: InputMode?, remote: InputMode?) {
        modeMenuItem.title = "本機：\(Self.name(local))　遠端：\(remote.map { Self.name($0) } ?? "尚未得知")"
        modeMenuItem.toolTip = "遠端輸入法是依 Caps Lock 次數推算的；若與遠端畫面不符，請用「對齊遠端輸入法…」"
    }

    /// Mimics the menu's shortcut column for a gesture that cannot be a real
    /// key equivalent (Command, then Shift, released without another key).
    private static func titleWithHint(_ title: String, hint: String) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 250)]
        let result = NSMutableAttributedString(
            string: title,
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        result.append(NSAttributedString(
            string: "\t" + hint,
            attributes: [.font: font, .paragraphStyle: paragraph, .foregroundColor: NSColor.secondaryLabelColor]
        ))
        return result
    }

    private static func name(_ mode: InputMode?) -> String {
        switch mode {
        case .english: return "ABC"
        case .chinese: return "注音"
        case nil: return "其他"
        }
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
