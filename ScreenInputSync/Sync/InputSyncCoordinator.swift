final class InputSyncCoordinator {
    private let sourceController: InputSourceControlling
    private let remoteEmitter: RemoteToggleEmitting
    private let onModeChanged: (InputMode) -> Void
    private let onError: (Error) -> Void

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

    /// Switches only the remote Mac's input source via its F17 shortcut.
    func toggleRemote() {
        remoteEmitter.emitRemoteToggle()
    }

    @discardableResult
    func alignLocal(to mode: InputMode) -> Bool {
        do {
            try sourceController.select(mode)
            onModeChanged(mode)
            return true
        } catch {
            onError(error)
            return false
        }
    }
}
