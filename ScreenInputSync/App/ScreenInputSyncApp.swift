import AppKit

enum AppMetadata {
    static let displayName = "ScreenInputSync"
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = MenuBarController()
        menuBarController = menu

        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        let hud = ResyncHUDController()
        hudController = hud

        let sourceController = CarbonInputSourceController()
        let coordinator = InputSyncCoordinator(
            sourceController: sourceController,
            remoteEmitter: F17RemoteToggleEmitter(),
            onModeChanged: { mode in
                DispatchQueue.main.async { menu.updateMode(mode) }
            },
            onError: { error in
                DispatchQueue.main.async { menu.updateStatus("Error: \(error.localizedDescription)") }
            }
        )
        inputSyncCoordinator = coordinator

        let loginController = LoginItemController { error in
            DispatchQueue.main.async {
                menu.updateStatus("Login item error: \(error.localizedDescription)")
            }
        }
        loginItemController = loginController
        loginController.enableIfNeeded()
        menu.setLaunchAtLogin(loginController.isEnabled)

        let eventTap = EventTapController(
            frontmostChecker: WorkspaceFrontmostApplicationChecker()
        ) { [weak self] decision in
            DispatchQueue.main.async { self?.handle(decision) }
        }
        eventTapController = eventTap

        menu.onResync = { [weak eventTap, weak hud] in
            eventTap?.setHUDActive(true)
            hud?.show()
        }
        menu.onLaunchAtLoginChanged = { [weak loginController, weak menu] enabled in
            loginController?.setEnabled(enabled)
            menu?.setLaunchAtLogin(loginController?.isEnabled == true)
        }

        do {
            let mode = try sourceController.currentMode()
            menu.updateMode(mode)
        } catch {
            menu.updateStatus("Error: \(error.localizedDescription)")
        }

        if PermissionController().ensureKeyboardPermissions() {
            menu.updateStatus(eventTap.start() ? "Active in Screen Sharing" : "Unable to start keyboard monitor")
        } else {
            menu.updateStatus("Grant Accessibility and Input Monitoring, then relaunch")
        }
    }

    private func handle(_ decision: RoutingDecision) {
        switch decision {
        case .toggleBoth:
            inputSyncCoordinator?.toggleBoth()
        case .showResyncHUD:
            hudController?.show()
        case .chooseEnglish:
            inputSyncCoordinator?.alignLocal(to: .english)
            hudController?.showConfirmation(.english)
        case .chooseChinese:
            inputSyncCoordinator?.alignLocal(to: .chinese)
            hudController?.showConfirmation(.chinese)
        case .dismissHUD:
            hudController?.dismiss()
        case .reenableTap:
            menuBarController?.updateStatus("Keyboard monitor recovered")
        case .passThrough, .suppress:
            break
        }
    }
}
