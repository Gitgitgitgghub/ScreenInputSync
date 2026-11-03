/// Keeps the local input source equal to the remote Mac's while Screen
/// Sharing is frontmost.
///
/// Screen Sharing converts keystrokes through the *local* input source before
/// sending characters to the remote (verified 2026-11-03: local Zhuyin turns
/// remote-ABC `abc` into ㄇㄖㄏ; local ABC prevents remote Zhuyin composition).
/// Both sides must therefore match. The remote cannot be inspected, so its
/// mode is tracked: every Caps Lock press flips it via F17, and the resync
/// HUD can declare it explicitly.
final class InputSyncCoordinator {
    private let sourceController: InputSourceControlling
    private let remoteEmitter: RemoteToggleEmitting
    private let onModeChanged: (InputMode) -> Void
    private let onError: (Error) -> Void

    private(set) var remoteMode: InputMode?
    private var modeBeforeScreenSharing: InputMode?
    private(set) var isInScreenSharing = false

    init(
        sourceController: InputSourceControlling,
        remoteEmitter: RemoteToggleEmitting,
        onModeChanged: @escaping (InputMode) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.sourceController = sourceController
        self.remoteEmitter = remoteEmitter
        self.onModeChanged = onModeChanged
        self.onError = onError
    }

    func screenSharingDidBecomeFrontmost() {
        guard !isInScreenSharing else { return }
        isInScreenSharing = true
        let current = try? sourceController.currentMode()
        modeBeforeScreenSharing = current
        if remoteMode == nil { remoteMode = current }
        enforceRemoteMode()
    }

    func screenSharingDidResignFrontmost() {
        guard isInScreenSharing else { return }
        isInScreenSharing = false
        defer { modeBeforeScreenSharing = nil }
        guard let mode = modeBeforeScreenSharing else { return }
        selectIfNeeded(mode)
    }

    /// Re-applies the remote mode if something switched the local source
    /// while Screen Sharing is frontmost (e.g. the system's own Caps Lock
    /// ABC switching or Control-Space).
    func localSourceDidChange() {
        guard isInScreenSharing else { return }
        enforceRemoteMode()
    }

    /// Caps Lock inside Screen Sharing: flip both Macs.
    func toggleBoth() {
        if !isInScreenSharing { screenSharingDidBecomeFrontmost() }
        do {
            let base = try remoteMode ?? sourceController.currentMode()
            let next = base.opposite
            try sourceController.select(next)
            remoteMode = next
            remoteEmitter.emitRemoteToggle()
            onModeChanged(next)
        } catch {
            onError(error)
        }
    }

    /// Resync: the user declares the remote's actual mode. Never emits F17.
    @discardableResult
    func alignLocal(to mode: InputMode) -> Bool {
        remoteMode = mode
        do {
            try sourceController.select(mode)
            onModeChanged(mode)
            return true
        } catch {
            onError(error)
            return false
        }
    }

    private func enforceRemoteMode() {
        guard let remoteMode else { return }
        selectIfNeeded(remoteMode)
    }

    private func selectIfNeeded(_ mode: InputMode) {
        guard (try? sourceController.currentMode()) != mode else { return }
        do {
            try sourceController.select(mode)
            onModeChanged(mode)
        } catch {
            onError(error)
        }
    }
}
