import AppKit
import Darwin

/// An app opened straight from Downloads runs from a random read-only copy
/// (App Translocation), which breaks launch at login. This offers to move the
/// app into /Applications and relaunch it from there.
@MainActor
enum ApplicationMover {
    /// Returns true when the app is quitting (to relaunch from /Applications
    /// or because the user declined); the caller should stop launching.
    static func moveToApplicationsIfTranslocated() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        guard AppTranslocation.isTranslocated(bundleURL) else { return false }

        NSApp.activate(ignoringOtherApps: true)
        guard let originalURL = AppTranslocation.originalURL(of: bundleURL) else {
            showManualMoveAlert()
            NSApp.terminate(nil)
            return true
        }

        let alert = NSAlert()
        alert.messageText = "請把 ScreenInputSync 移到「應用程式」"
        alert.informativeText = "直接在「下載」資料夾開啟時，macOS 會從暫存位置執行 App，部分功能會無法正常運作。"
        alert.addButton(withTitle: "移到應用程式並重新開啟")
        alert.addButton(withTitle: "結束")
        guard alert.runModal() == .alertFirstButtonReturn else {
            NSApp.terminate(nil)
            return true
        }

        do {
            let installedURL = try install(originalURL)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: installedURL, configuration: configuration) { _, _ in
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        } catch {
            showManualMoveAlert(error: error)
            NSApp.terminate(nil)
        }
        return true
    }

    private static func install(_ originalURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let applications = try fileManager.url(for: .applicationDirectory, in: .localDomainMask, appropriateFor: nil, create: false)
        let destination = applications.appendingPathComponent(originalURL.lastPathComponent)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.trashItem(at: destination, resultingItemURL: nil)
        }
        do {
            try fileManager.moveItem(at: originalURL, to: destination)
        } catch {
            // The original may sit on a read-only disk image.
            try fileManager.copyItem(at: originalURL, to: destination)
        }
        removeQuarantine(from: destination)
        return destination
    }

    /// The user already approved this app in Gatekeeper; without the
    /// quarantine flag the moved copy is no longer translocated.
    private static func removeQuarantine(from url: URL) {
        var paths = [url.path]
        if let enumerator = FileManager.default.enumerator(atPath: url.path) {
            while let relative = enumerator.nextObject() as? String {
                paths.append(url.appendingPathComponent(relative).path)
            }
        }
        for path in paths {
            removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW)
        }
    }

    private static func showManualMoveAlert(error: Error? = nil) {
        let alert = NSAlert()
        alert.messageText = "請把 ScreenInputSync 移到「應用程式」"
        var text = "請在 Finder 把 ScreenInputSync 拖進「應用程式」資料夾，再從那裡開啟。"
        if let error { text += "\n\n無法自動移動：\(error.localizedDescription)" }
        alert.informativeText = text
        alert.addButton(withTitle: "結束")
        alert.runModal()
    }
}

/// Wraps the Security framework's translocation functions. They are exported
/// but not in the public headers, so they are looked up at runtime.
enum AppTranslocation {
    private typealias IsTranslocatedFunction = @convention(c) (
        CFURL, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<Unmanaged<CFError>?>?
    ) -> UInt8
    private typealias OriginalPathFunction = @convention(c) (
        CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?
    ) -> Unmanaged<CFURL>?

    static func isTranslocated(_ url: URL) -> Bool {
        if let function: IsTranslocatedFunction = securitySymbol("SecTranslocateIsTranslocatedURL") {
            var result = false
            if function(url as CFURL, &result, nil) != 0 { return result }
        }
        return url.path.contains("/AppTranslocation/")
    }

    static func originalURL(of url: URL) -> URL? {
        guard let function: OriginalPathFunction = securitySymbol("SecTranslocateCreateOriginalPathForURL"),
              let original = function(url as CFURL, nil)?.takeRetainedValue() as URL?,
              original != url
        else { return nil }
        return original
    }

    private static func securitySymbol<T>(_ name: String) -> T? {
        guard let handle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(handle, name)
        else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
