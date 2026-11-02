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

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
    }
}
