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
    private var workspaceObserver: NSObjectProtocol?
    private var keyboardStatus = "Starting keyboard monitor…"

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        let menu = MenuBarController()
        menuBarController = menu

        let hud = ResyncHUDController()
        hudController = hud

        let sourceController = CarbonInputSourceController()
        let coordinator = InputSyncCoordinator(
            sourceController: sourceController,
            remoteEmitter: F17RemoteToggleEmitter(),
            onModeChanged: { [weak self] mode in
                DispatchQueue.main.async {
                    menu.updateMode(mode)
                    menu.updateStatus(self?.keyboardStatus ?? "Active in Screen Sharing")
                }
            },
            onError: { error in
                DispatchQueue.main.async { menu.updateStatus("Error: \(error.localizedDescription)") }
            }
        )
        inputSyncCoordinator = coordinator

        let loginController = LoginItemController(onError: { error in
            DispatchQueue.main.async {
                menu.updateLoginStatus("Login item error: \(error.localizedDescription)")
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
        eventTapController = eventTap

        menu.onResync = { [weak eventTap, weak hud] in
            guard frontmostChecker.screenSharingIsFrontmost else {
                menu.updateStatus("Resync is available only while Screen Sharing is frontmost")
                return
            }
            eventTap?.setHUDActive(true)
            hud?.show()
        }
        menu.onLaunchAtLoginSelected = { [weak self, weak loginController] in
            loginController?.handleMenuSelection()
            self?.updateLoginPresentation()
        }
        menu.onMenuWillOpen = { [weak self, weak menu] in
            self?.updateLoginPresentation()
            do {
                menu?.updateMode(try sourceController.currentMode())
                menu?.updateStatus(self?.keyboardStatus ?? "Active in Screen Sharing")
            } catch {
                menu?.updateStatus("Error: \(error.localizedDescription)")
            }
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLoginPresentation()
                guard !frontmostChecker.screenSharingIsFrontmost else {
                    self?.eventTapController?.clearCapsLock()
                    return
                }
                self?.eventTapController?.setHUDActive(false)
                self?.hudController?.dismiss()
            }
        }

        if PermissionController().ensureKeyboardPermissions() {
            updateKeyboardStatus(eventTap.start() ? "Active in Screen Sharing" : "Unable to start keyboard monitor")
        } else {
            updateKeyboardStatus("Grant Accessibility and Input Monitoring, then relaunch")
        }

        do {
            menu.updateMode(try sourceController.currentMode())
        } catch {
            menu.updateStatus("Error: \(error.localizedDescription)")
        }
    }

    private func handle(_ decision: RoutingDecision) {
        switch decision {
        case .toggleRemote:
            inputSyncCoordinator?.toggleRemote()
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
            updateKeyboardStatus("Keyboard monitor recovered")
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
                ? "Approval required — click Launch at Login to open System Settings"
                : nil
        )
    }
}
