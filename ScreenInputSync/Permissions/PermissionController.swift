import ApplicationServices
import CoreGraphics

struct PermissionController {
    func ensureKeyboardPermissions() -> Bool {
        let accessibilityGranted = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )

        let inputMonitoringGranted: Bool
        if CGPreflightListenEventAccess() {
            inputMonitoringGranted = true
        } else {
            inputMonitoringGranted = CGRequestListenEventAccess()
        }

        return accessibilityGranted && inputMonitoringGranted
    }
}
