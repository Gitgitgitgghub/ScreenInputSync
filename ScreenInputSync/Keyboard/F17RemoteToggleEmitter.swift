import CoreGraphics

struct F17RemoteToggleEmitter: RemoteToggleEmitting {
    private static let f17KeyCode: CGKeyCode = 0x40

    func emitRemoteToggle() {
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: Self.f17KeyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: Self.f17KeyCode,
            keyDown: false
        ) else {
            return
        }
        keyDown.flags = []
        keyUp.flags = []
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }
}
