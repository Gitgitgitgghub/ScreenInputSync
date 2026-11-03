import ApplicationServices

struct PermissionController {
    /// The active (modifying) keyboard event tap and posting F17 both require
    /// Accessibility; a modifying tap does not need Input Monitoring.
    func ensureKeyboardPermissions() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
