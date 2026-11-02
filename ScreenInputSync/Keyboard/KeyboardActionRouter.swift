enum KeyboardEvent: Equatable {
    case commandDown
    case commandUp
    case shiftDown
    case shiftUp
    case capsLockDown
    case capsLockUp
    case englishKeyDown
    case chineseKeyDown
    case escapeKeyDown
    case otherKeyDown
    case tapDisabled
}

enum RoutingDecision: Equatable {
    case passThrough
    case suppress
    case toggleBoth
    case showResyncHUD
    case chooseEnglish
    case chooseChinese
    case dismissHUD
    case reenableTap

    var suppressesEvent: Bool {
        self != .passThrough && self != .reenableTap
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
            _ = recognizer.handle(.reset)
            hudIsActive = false
            return .passThrough
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
        case .capsLockDown:
            return .toggleBoth
        case .capsLockUp:
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
