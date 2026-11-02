enum ModifierSequenceEvent: Equatable {
    case commandDown
    case shiftDown
    case commandUp
    case shiftUp
    case otherKeyDown
    case reset
}

enum ModifierSequenceResult: Equatable {
    case ignored
    case pending
    case triggered
    case cancelled
}

struct ModifierSequenceRecognizer {
    private enum State {
        case idle
        case commandOnly
        case chord(commandDown: Bool, shiftDown: Bool)
        case blocked(commandDown: Bool, shiftDown: Bool)
    }

    private var state: State = .idle

    mutating func handle(_ event: ModifierSequenceEvent) -> ModifierSequenceResult {
        switch event {
        case .reset:
            let wasPending = !isIdle
            state = .idle
            return wasPending ? .cancelled : .ignored

        case .otherKeyDown:
            switch state {
            case .commandOnly:
                state = .blocked(commandDown: true, shiftDown: false)
                return .cancelled
            case let .chord(commandDown, shiftDown):
                state = .blocked(commandDown: commandDown, shiftDown: shiftDown)
                return .cancelled
            case .idle, .blocked:
                return .ignored
            }

        case .commandDown:
            return commandDidChange(isDown: true)
        case .commandUp:
            return commandDidChange(isDown: false)
        case .shiftDown:
            return shiftDidChange(isDown: true)
        case .shiftUp:
            return shiftDidChange(isDown: false)
        }
    }

    private var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    private mutating func commandDidChange(isDown: Bool) -> ModifierSequenceResult {
        switch (state, isDown) {
        case (.idle, true):
            state = .commandOnly
            return .pending
        case (.commandOnly, false):
            state = .idle
            return .cancelled
        case let (.chord(_, shiftDown), false):
            state = .chord(commandDown: false, shiftDown: shiftDown)
            return completeChordIfReleased()
        case let (.blocked(_, shiftDown), _):
            state = blockedState(commandDown: isDown, shiftDown: shiftDown)
            return .ignored
        default:
            return .ignored
        }
    }

    private mutating func shiftDidChange(isDown: Bool) -> ModifierSequenceResult {
        switch (state, isDown) {
        case (.idle, true):
            state = .blocked(commandDown: false, shiftDown: true)
            return .ignored
        case (.commandOnly, true):
            state = .chord(commandDown: true, shiftDown: true)
            return .pending
        case let (.chord(commandDown, _), false):
            state = .chord(commandDown: commandDown, shiftDown: false)
            return completeChordIfReleased()
        case let (.blocked(commandDown, _), _):
            state = blockedState(commandDown: commandDown, shiftDown: isDown)
            return .ignored
        default:
            return .ignored
        }
    }

    private mutating func completeChordIfReleased() -> ModifierSequenceResult {
        guard case let .chord(commandDown, shiftDown) = state,
              !commandDown,
              !shiftDown else {
            return .pending
        }

        state = .idle
        return .triggered
    }

    private func blockedState(commandDown: Bool, shiftDown: Bool) -> State {
        commandDown || shiftDown
            ? .blocked(commandDown: commandDown, shiftDown: shiftDown)
            : .idle
    }
}
