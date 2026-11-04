import CoreGraphics

final class EventTapController: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var router = KeyboardActionRouter()
    private let frontmostChecker: FrontmostApplicationChecking
    private let capsLockState: CapsLockStateResetting
    private let onDecision: (RoutingDecision) -> Void
    /// Set on the main thread, which also runs the tap callback.
    var inputSwitchShortcuts: [InputSwitchShortcut] = []

    init(
        frontmostChecker: FrontmostApplicationChecking,
        capsLockState: CapsLockStateResetting = HIDCapsLockStateController(),
        onDecision: @escaping (RoutingDecision) -> Void
    ) {
        self.frontmostChecker = frontmostChecker
        self.capsLockState = capsLockState
        self.onDecision = onDecision
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Keeps the local Caps Lock latch off so no lock state leaks to the remote.
    func clearCapsLock() {
        capsLockState.clearCapsLock()
    }

    func setHUDActive(_ active: Bool) {
        router.setHUDActive(active)
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        return controller.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            _ = router.route(.tapDisabled, screenSharingIsFrontmost: false)
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            onDecision(.dismissHUD)
            onDecision(.reenableTap)
            return Unmanaged.passUnretained(event)
        }

        let screenSharingIsFrontmost = frontmostChecker.screenSharingIsFrontmost
        let keyboardEvent = keyboardEvent(type: type, event: event)
        if screenSharingIsFrontmost {
            // Never forward a Caps Lock state to the remote: its Zhuyin input
            // method treats Caps Lock as "type English", which desyncs the
            // remote's behavior from its displayed input source.
            event.flags.remove(.maskAlphaShift)
        }

        // Checked for every modifier, including Control and Option, which
        // are not mapped to keyboard events.
        if type == .flagsChanged,
           event.flags.intersection(KeyboardEventAdapter.heldModifiers).isEmpty,
           router.modifiersReleased(screenSharingIsFrontmost: screenSharingIsFrontmost) == .toggleBoth {
            onDecision(.toggleBoth)
        }

        guard let keyboardEvent else {
            return Unmanaged.passUnretained(event)
        }

        let decision = router.route(keyboardEvent, screenSharingIsFrontmost: screenSharingIsFrontmost)
        if screenSharingIsFrontmost, decision.suppressesEvent,
           [.capsLockPressed, .capsLockReleased, .lockStateChanged].contains(keyboardEvent) {
            capsLockState.clearCapsLock()
        }
        if decision != .passThrough, decision != .suppress { onDecision(decision) }
        return decision.suppressesEvent ? nil : Unmanaged.passUnretained(event)
    }

    private func keyboardEvent(type: CGEventType, event: CGEvent) -> KeyboardEvent? {
        KeyboardEventAdapter.map(
            type: type,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            flags: event.flags,
            isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            shortcuts: inputSwitchShortcuts
        )
    }
}

enum KeyboardEventAdapter {
    static let heldModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    static func map(
        type: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags,
        isAutorepeat: Bool = false,
        shortcuts: [InputSwitchShortcut] = []
    ) -> KeyboardEvent? {
        if type == .flagsChanged {
            switch keyCode {
            case 54, 55:
                return flags.contains(.maskCommand) ? .commandDown : .commandUp
            case 56, 60:
                return flags.contains(.maskShift) ? .shiftDown : .shiftUp
            case 255:
                // Synthetic lock-state change (system or IOHIDSetModifierLockState).
                return .lockStateChanged
            case 57:
                // With macOS "Use Caps Lock to switch to and from ABC", a tap
                // emits flagsChanged on press (latch on) and on release (latch
                // off, after the system clears it while switching input).
                return flags.contains(.maskAlphaShift) ? .capsLockPressed : .capsLockReleased
            default:
                return nil
            }
        }

        if type == .keyUp {
            return shortcuts.contains { $0.keyCode == keyCode } ? .inputSwitchShortcutKeyUp : nil
        }
        guard type == .keyDown else { return nil }
        if shortcuts.contains(where: { $0.matches(keyCode: keyCode, flags: flags) }) {
            return isAutorepeat
                ? .inputSwitchShortcutRepeated
                : .inputSwitchShortcutPressed(modifiersHeld: !flags.intersection(heldModifiers).isEmpty)
        }
        switch keyCode {
        case 14: return .englishKeyDown
        case 8: return .chineseKeyDown
        case 53: return .escapeKeyDown
        default: return .otherKeyDown
        }
    }
}
