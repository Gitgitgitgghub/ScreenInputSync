import CoreFoundation
import CoreGraphics

/// A keyboard shortcut the user set in System Settings to switch input
/// sources, such as Control-Space or Command-Space.
struct InputSwitchShortcut: Equatable, Sendable {
    /// Modifiers that must match exactly. Function keys and arrows also carry
    /// the fn flag, both in the system setting and in key events.
    static let relevantModifiers: CGEventFlags = [
        .maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn,
    ]

    let keyCode: Int64
    let modifiers: CGEventFlags

    init(keyCode: Int64, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
    }

    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == self.keyCode && flags.intersection(Self.relevantModifiers) == modifiers
    }
}

/// Reads the "Select the previous/next input source" shortcuts from
/// System Settings → Keyboard → Keyboard Shortcuts → Input Sources.
enum SystemInputSwitchShortcuts {
    private static let domain = "com.apple.symbolichotkeys"
    private static let key = "AppleSymbolicHotKeys"

    /// Symbolic hotkey IDs and the macOS defaults used when the user never
    /// changed them (the entry is then absent from the preferences).
    private static let hotkeys: [(id: String, fallback: InputSwitchShortcut)] = [
        ("60", InputSwitchShortcut(keyCode: 49, modifiers: [.maskControl])),
        ("61", InputSwitchShortcut(keyCode: 49, modifiers: [.maskControl, .maskAlternate])),
    ]

    static func load() -> [InputSwitchShortcut] {
        CFPreferencesAppSynchronize(domain as CFString)
        let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? [String: Any]
        return parse(value ?? [:])
    }

    static func parse(_ symbolicHotKeys: [String: Any]) -> [InputSwitchShortcut] {
        hotkeys.compactMap { id, fallback in
            guard let entry = symbolicHotKeys[id] as? [String: Any] else { return fallback }
            guard entry["enabled"] as? Bool == true,
                  let value = entry["value"] as? [String: Any],
                  let parameters = value["parameters"] as? [Int],
                  parameters.count >= 3,
                  parameters[1] != 65535
            else { return nil }
            return InputSwitchShortcut(
                keyCode: Int64(parameters[1]),
                modifiers: CGEventFlags(rawValue: UInt64(parameters[2]))
            )
        }
    }
}
