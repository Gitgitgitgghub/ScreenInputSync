import CoreGraphics

final class EventTapController: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var router = KeyboardActionRouter()
    private let frontmostChecker: FrontmostApplicationChecking
    private let onDecision: (RoutingDecision) -> Void

    init(
        frontmostChecker: FrontmostApplicationChecking,
        onDecision: @escaping (RoutingDecision) -> Void
    ) {
        self.frontmostChecker = frontmostChecker
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

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
        router.setHUDActive(false)
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
            onDecision(.reenableTap)
            return Unmanaged.passUnretained(event)
        }

        guard let keyboardEvent = keyboardEvent(type: type, event: event) else {
            return Unmanaged.passUnretained(event)
        }

        let decision = router.route(
            keyboardEvent,
            screenSharingIsFrontmost: frontmostChecker.screenSharingIsFrontmost
        )
        if decision != .passThrough { onDecision(decision) }
        return decision.suppressesEvent ? nil : Unmanaged.passUnretained(event)
    }

    private func keyboardEvent(type: CGEventType, event: CGEvent) -> KeyboardEvent? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .flagsChanged {
            switch keyCode {
            case 54, 55:
                return event.flags.contains(.maskCommand) ? .commandDown : .commandUp
            case 56, 60:
                return event.flags.contains(.maskShift) ? .shiftDown : .shiftUp
            case 57:
                return event.flags.contains(.maskAlphaShift) ? .capsLockDown : .capsLockUp
            default:
                return nil
            }
        }

        if keyCode == 57 {
            return type == .keyDown ? .capsLockDown : .capsLockUp
        }
        guard type == .keyDown else { return nil }
        switch keyCode {
        case 14: return .englishKeyDown
        case 8: return .chineseKeyDown
        case 53: return .escapeKeyDown
        default: return .otherKeyDown
        }
    }
}
