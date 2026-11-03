/// Keeps the local Mac on ABC while Screen Sharing is frontmost.
///
/// Screen Sharing forwards what the local input method produces, so a local
/// Zhuyin source rewrites keystrokes (e.g. full-width Shift letters) before the
/// remote sees them. With local ABC, raw keys reach the remote and its own
/// input source alone decides how typing behaves.
final class LocalInputGuard {
    private let sourceController: InputSourceControlling
    private let onError: (Error) -> Void
    private var modeBeforeScreenSharing: InputMode?
    private var isGuarding = false

    init(
        sourceController: InputSourceControlling,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.sourceController = sourceController
        self.onError = onError
    }

    func screenSharingDidBecomeFrontmost() {
        if !isGuarding {
            isGuarding = true
            modeBeforeScreenSharing = try? sourceController.currentMode()
        }
        enforceEnglish()
    }

    func screenSharingDidResignFrontmost() {
        guard isGuarding else { return }
        isGuarding = false
        defer { modeBeforeScreenSharing = nil }
        guard let mode = modeBeforeScreenSharing,
              (try? sourceController.currentMode()) != mode else { return }
        select(mode)
    }

    func localSourceDidChange() {
        guard isGuarding else { return }
        enforceEnglish()
    }

    private func enforceEnglish() {
        guard (try? sourceController.currentMode()) != .english else { return }
        select(.english)
    }

    private func select(_ mode: InputMode) {
        do {
            try sourceController.select(mode)
        } catch {
            onError(error)
        }
    }
}
