enum KeyboardEvent: Equatable, Sendable {
    case commandDown
    case commandUp
    case shiftDown
    case shiftUp
    case capsLockPressed
    case capsLockReleased
    case lockStateChanged
    /// The user's own input-switch shortcut (e.g. Control-Space). When
    /// modifiers are held, the switch waits until they are released so the
    /// remote receives a bare F17 instead of, say, Control-F17.
    case inputSwitchShortcutPressed(modifiersHeld: Bool)
    case inputSwitchShortcutRepeated
    case inputSwitchShortcutKeyUp
    case englishKeyDown
    case chineseKeyDown
    case escapeKeyDown
    case otherKeyDown
    case tapDisabled
}

enum RoutingDecision: Equatable, Sendable {
    case passThrough
    case suppress
    case toggleBoth
    case showResyncHUD
    case chooseEnglish
    case chooseChinese
    case dismissHUD
    case dismissHUDPassingThrough
    case reenableTap

    var suppressesEvent: Bool {
        switch self {
        case .passThrough, .reenableTap, .showResyncHUD, .dismissHUDPassingThrough:
            return false
        default:
            return true
        }
    }
}

struct KeyboardActionRouter {
    private var recognizer = ModifierChordRecognizer()
    private var hudIsActive = false
    private var pendingShortcutToggles = 0
    private var shortcutKeyIsDown = false

    mutating func setHUDActive(_ active: Bool) {
        hudIsActive = active
        if !active { _ = recognizer.handle(.reset) }
    }

    /// Any other input while Command or Shift is held (another modifier, or a
    /// key or click found through the hardware input count) makes it a key
    /// combination, never the bare Command-Shift chord.
    mutating func interruptChord() {
        _ = recognizer.handle(.otherKeyDown)
    }

    mutating func route(
        _ event: KeyboardEvent,
        screenSharingIsFrontmost: Bool
    ) -> RoutingDecision {
        if event == .tapDisabled {
            _ = recognizer.handle(.reset)
            hudIsActive = false
            resetShortcutState()
            return .reenableTap
        }

        guard screenSharingIsFrontmost else {
            let shouldDismissHUD = hudIsActive
            _ = recognizer.handle(.reset)
            hudIsActive = false
            resetShortcutState()
            return shouldDismissHUD ? .dismissHUDPassingThrough : .passThrough
        }

        if hudIsActive {
            switch event {
            case .englishKeyDown:
                hudIsActive = false
                return .chooseEnglish
            case .chineseKeyDown:
                hudIsActive = false
                return .chooseChinese
            case .escapeKeyDown:
                hudIsActive = false
                return .dismissHUD
            default:
                break
            }
        }

        switch event {
        case .capsLockPressed:
            // Caps Lock never reaches the remote; both Macs are switched explicitly.
            return .toggleBoth
        case .capsLockReleased, .lockStateChanged:
            return .suppress
        case .inputSwitchShortcutPressed(let modifiersHeld):
            // The shortcut never reaches the local system or the remote.
            _ = recognizer.handle(.otherKeyDown)
            shortcutKeyIsDown = true
            guard modifiersHeld else { return .toggleBoth }
            pendingShortcutToggles += 1
            return .suppress
        case .inputSwitchShortcutRepeated:
            return shortcutKeyIsDown ? .suppress : .passThrough
        case .inputSwitchShortcutKeyUp:
            guard shortcutKeyIsDown else { return .passThrough }
            shortcutKeyIsDown = false
            return .suppress
        case .commandDown:
            return chordDecision(.commandDown)
        case .commandUp:
            return chordDecision(.commandUp)
        case .shiftDown:
            return chordDecision(.shiftDown)
        case .shiftUp:
            return chordDecision(.shiftUp)
        case .englishKeyDown, .chineseKeyDown, .escapeKeyDown, .otherKeyDown:
            _ = recognizer.handle(.otherKeyDown)
            return .passThrough
        case .tapDisabled:
            return .reenableTap
        }
    }

    /// Called when every modifier key is up. Applies the switches requested
    /// with the input-switch shortcut while modifiers were held; pressing it
    /// twice before releasing cancels out, like the system shortcut.
    mutating func modifiersReleased(screenSharingIsFrontmost: Bool) -> RoutingDecision {
        defer { pendingShortcutToggles = 0 }
        guard screenSharingIsFrontmost, pendingShortcutToggles % 2 == 1 else { return .passThrough }
        return .toggleBoth
    }

    private mutating func resetShortcutState() {
        pendingShortcutToggles = 0
        shortcutKeyIsDown = false
    }

    private mutating func chordDecision(_ event: ModifierChordEvent) -> RoutingDecision {
        guard recognizer.handle(event) else { return .passThrough }
        hudIsActive = true
        return .showResyncHUD
    }
}
