enum ModifierChordEvent: Equatable {
    case commandDown
    case commandUp
    case shiftDown
    case shiftUp
    case otherKeyDown
    case reset
}

/// Recognizes Command + Shift pressed together (either order) and released
/// without any other key in between. Any other key turns the chord into a
/// normal shortcut (e.g. Command-Shift-P), which never triggers.
struct ModifierChordRecognizer {
    private var commandDown = false
    private var shiftDown = false
    private var sawBoth = false
    private var interrupted = false

    /// Returns true when the chord completes.
    mutating func handle(_ event: ModifierChordEvent) -> Bool {
        switch event {
        case .reset:
            self = ModifierChordRecognizer()
            return false
        case .otherKeyDown:
            if commandDown || shiftDown { interrupted = true }
            return false
        case .commandDown: commandDown = true
        case .commandUp: commandDown = false
        case .shiftDown: shiftDown = true
        case .shiftUp: shiftDown = false
        }

        if commandDown && shiftDown { sawBoth = true }
        guard !commandDown, !shiftDown else { return false }

        let triggered = sawBoth && !interrupted
        self = ModifierChordRecognizer()
        return triggered
    }
}
