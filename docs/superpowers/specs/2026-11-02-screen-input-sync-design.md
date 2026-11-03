# ScreenInputSync Design

Last revised: 2026-11-03

## Intent

A local-only macOS menu bar utility that keeps typing in an Apple Screen Sharing session consistent with the remote Mac's displayed input source (ABC / Traditional Zhuyin), switched with one Caps Lock press.

## Key finding

Screen Sharing converts keystrokes through the **local** input source before sending them, so the local source must equal the remote one:

| Local | Remote | Result |
|---|---|---|
| Zhuyin | Zhuyin | composition works |
| ABC | Zhuyin | literal letters, no composition |
| ABC | ABC | correct half-width text |
| Zhuyin | ABC | letters become Bopomofo symbols |

Forwarding the Caps Lock lock state also puts the remote Zhuyin into its English mode, so Caps Lock must never reach the remote.

## Behavior (while `com.apple.ScreenSharing` is frontmost)

- Caps Lock press: select the opposite local source explicitly, emit F17 (remote shortcut "Select the previous input source"). Suppress the Caps Lock press/release and synthetic lock-state (keycode 255) events, strip `maskAlphaShift` from forwarded events, and clear the local HID Caps Lock latch.
- The coordinator tracks the remote mode (unknown remote state cannot be read). On entering Screen Sharing the local source is set to it; if anything switches the local source meanwhile it is re-applied; on leaving, the user's previous local source is restored.
- Resync: Command + Shift pressed together (any order) and released with no other key opens a HUD; `E`/`C` declares the remote mode and aligns only the local source (never F17); `Esc` cancels. Command-Shift-letter shortcuts pass through.
- Outside Screen Sharing everything passes through unchanged.

## Architecture

- `EventTapController` (CGEventTap) → `KeyboardEventAdapter` → `KeyboardActionRouter` (pure, with `ModifierChordRecognizer`) → app delegate.
- `InputSyncCoordinator` owns the tracked remote mode and local enforcement; depends on `InputSourceControlling` (Carbon TIS) and `RemoteToggleEmitting` (F17) for deterministic tests.
- `HIDCapsLockStateController` clears the Caps Lock latch via `IOHIDSetModifierLockState`.
- `ResyncHUDController` is a non-activating rounded panel; `SMAppService.mainApp` provides launch at login.

## Constraints

- macOS 14+, Swift 6, no third-party runtime dependencies.
- Requires Accessibility and Input Monitoring permission.
- Signed with a stable Apple Development identity so permissions survive rebuilds.
