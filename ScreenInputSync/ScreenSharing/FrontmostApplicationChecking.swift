import AppKit

protocol FrontmostApplicationChecking {
    var screenSharingIsFrontmost: Bool { get }
}

struct WorkspaceFrontmostApplicationChecker: FrontmostApplicationChecking {
    static let screenSharingBundleIdentifier = "com.apple.ScreenSharing"

    var screenSharingIsFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            == Self.screenSharingBundleIdentifier
    }
}
