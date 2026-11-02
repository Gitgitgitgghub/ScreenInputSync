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

    func toggleBoth() {
        do {
            let nextMode = try sourceController.currentMode().opposite
            try sourceController.select(nextMode)
            remoteEmitter.emitRemoteToggle()
            onModeChanged(nextMode)
        } catch {
            onError(error)
        }
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
