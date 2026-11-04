import AppKit
import Carbon.HIToolbox

enum AppMetadata {
    static let displayName = "ScreenInputSync"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
}

@main
@MainActor
enum ScreenInputSyncApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = ScreenInputSyncAppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
final class ScreenInputSyncAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var inputSyncCoordinator: InputSyncCoordinator?
    private var eventTapController: EventTapController?
    private var hudController: ResyncHUDController?
    private var loginItemController: LoginItemController?
    private var workspaceObserver: NSObjectProtocol?
    private var inputSourceObserver: NSObjectProtocol?
    private var keyboardStatus = "啟動中…"

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        if ApplicationMover.moveToApplicationsIfTranslocated() { return }

        let menu = MenuBarController()
        menuBarController = menu

        let hud = ResyncHUDController()
        hudController = hud

        let sourceController = CarbonInputSourceController()
        let coordinator = InputSyncCoordinator(
            sourceController: sourceController,
            remoteEmitter: F17RemoteToggleEmitter(),
            onModeChanged: { [weak self] _ in
                // A successful switch clears any previous error message.
                DispatchQueue.main.async { menu.updateStatus(self?.keyboardStatus ?? Self.activeStatus) }
            },
            onError: { error in
                DispatchQueue.main.async { menu.updateStatus("錯誤：\(error.localizedDescription)") }
            }
        )
        inputSyncCoordinator = coordinator

        let loginController = LoginItemController(onError: { error in
            DispatchQueue.main.async {
                menu.updateLoginStatus("登入項目錯誤：\(error.localizedDescription)")
            }
        })
        loginItemController = loginController
        loginController.enableIfNeeded()
        updateLoginPresentation()

        let frontmostChecker = WorkspaceFrontmostApplicationChecker()
        let eventTap = EventTapController(
            frontmostChecker: frontmostChecker
        ) { [weak self] decision in
            DispatchQueue.main.async { self?.handle(decision) }
        }
        eventTap.inputSwitchShortcuts = SystemInputSwitchShortcuts.load()
        eventTapController = eventTap

        menu.onResync = { [weak eventTap, weak hud] in
            guard frontmostChecker.screenSharingIsFrontmost else {
                hud?.showScreenSharingRequired()
                return
            }
            eventTap?.setHUDActive(true)
            hud?.show()
        }
        menu.onLaunchAtLoginSelected = { [weak self, weak loginController] in
            loginController?.handleMenuSelection()
            self?.updateLoginPresentation()
        }
        menu.onMenuWillOpen = { [weak self] in
            self?.updateLoginPresentation()
        }

        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in coordinator.localSourceDidChange() }
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLoginPresentation()
                guard !frontmostChecker.screenSharingIsFrontmost else {
                    // Pick up shortcut changes made in System Settings.
                    self?.eventTapController?.inputSwitchShortcuts = SystemInputSwitchShortcuts.load()
                    self?.eventTapController?.clearCapsLock()
                    coordinator.screenSharingDidBecomeFrontmost()
                    return
                }
                coordinator.screenSharingDidResignFrontmost()
                self?.eventTapController?.setHUDActive(false)
                self?.hudController?.dismiss()
            }
        }

        if PermissionController().ensureKeyboardPermissions() {
            updateKeyboardStatus(eventTap.start() ? Self.activeStatus : "無法啟動鍵盤監控，請重新開啟 App")
        } else {
            updateKeyboardStatus("請允許「輔助使用」後重新開啟")
        }

        if frontmostChecker.screenSharingIsFrontmost {
            coordinator.screenSharingDidBecomeFrontmost()
        }

    }

    private static let activeStatus = "運作中：在螢幕共享按 Caps Lock 切換"

    private func handle(_ decision: RoutingDecision) {
        switch decision {
        case .toggleBoth:
            inputSyncCoordinator?.toggleBoth()
        case .showResyncHUD:
            hudController?.show()
        case .chooseEnglish:
            if inputSyncCoordinator?.alignLocal(to: .english) == true {
                hudController?.showConfirmation(.english)
            } else {
                hudController?.dismiss()
            }
        case .chooseChinese:
            if inputSyncCoordinator?.alignLocal(to: .chinese) == true {
                hudController?.showConfirmation(.chinese)
            } else {
                hudController?.dismiss()
            }
        case .dismissHUD, .dismissHUDPassingThrough:
            hudController?.dismiss()
        case .reenableTap:
            updateKeyboardStatus(Self.activeStatus)
        case .passThrough, .suppress:
            break
        }
    }

    private func updateKeyboardStatus(_ text: String) {
        keyboardStatus = text
        menuBarController?.updateStatus(text)
    }

    private func updateLoginPresentation() {
        guard let controller = loginItemController else { return }
        menuBarController?.setLaunchAtLoginStatus(controller.status)
        menuBarController?.updateLoginStatus(
            controller.status == .requiresApproval
                ? "需要核准：點「登入時啟動」前往系統設定"
                : nil
        )
    }
}
