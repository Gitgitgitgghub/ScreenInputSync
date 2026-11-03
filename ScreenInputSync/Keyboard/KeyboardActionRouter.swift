enum KeyboardEvent: Equatable, Sendable {
    case commandDown
    case commandUp
    case shiftDown
    case shiftUp
    case capsLockPressed
    case capsLockReleased
    case lockStateChanged
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
    private var recognizer = ModifierSequenceRecognizer()
    private var hudIsActive = false

    mutating func setHUDActive(_ active: Bool) {
        hudIsActive = active
        if !active { _ = recognizer.handle(.reset) }
    }

    mutating func route(
        _ event: KeyboardEvent,
        screenSharingIsFrontmost: Bool
    ) -> RoutingDecision {
        if event == .tapDisabled {
            _ = recognizer.handle(.reset)
            hudIsActive = false
            return .reenableTap
        }

        guard screenSharingIsFrontmost else {
            let shouldDismissHUD = hudIsActive
            _ = recognizer.handle(.reset)
            hudIsActive = false
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
        case .commandDown:
            return decision(for: recognizer.handle(.commandDown))
        case .commandUp:
            return decision(for: recognizer.handle(.commandUp))
        case .shiftDown:
            return decision(for: recognizer.handle(.shiftDown))
        case .shiftUp:
            return decision(for: recognizer.handle(.shiftUp))
        case .englishKeyDown, .chineseKeyDown, .escapeKeyDown, .otherKeyDown:
            _ = recognizer.handle(.otherKeyDown)
            return .passThrough
        case .tapDisabled:
            return .reenableTap
        }
    }

    private mutating func decision(for result: ModifierSequenceResult) -> RoutingDecision {
        guard result == .triggered else { return .passThrough }
        hudIsActive = true
        return .showResyncHUD
    }
}
