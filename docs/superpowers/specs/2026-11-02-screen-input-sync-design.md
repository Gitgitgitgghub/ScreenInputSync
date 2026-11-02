# ScreenInputSync Design

## Intent

Build a local-only macOS menu bar utility that keeps the local Mac and an Apple Screen Sharing session aligned between ABC and Traditional Chinese Zhuyin while preserving a one-key Caps Lock workflow for coding and Chinese comments.

## User experience

- The utility launches automatically at login and has no Dock icon.
- Outside Apple Screen Sharing, Caps Lock behaves normally.
- While Apple Screen Sharing is frontmost, pressing Caps Lock is suppressed and the utility:
  1. explicitly changes the local input source between ABC and Traditional Chinese Zhuyin;
  2. emits F17 to Screen Sharing, where F17 is configured to change the remote input source.
- The tool shows the local source and status in a menu bar menu.
- To repair drift, the user presses Command first, then Shift, and releases both without pressing another key. A centered HUD asks for `E` (the remote is ABC) or `C` (the remote is Chinese). The choice explicitly aligns the local source to the remote without changing the remote source.
- Pressing another non-modifier key during Command-then-Shift cancels recognition so normal shortcuts such as Command-Shift-P are unaffected. Escape dismisses the HUD.

## Architecture

- A native Swift/AppKit menu bar application uses a `CGEventTap` to observe and suppress keyboard events only while `com.apple.ScreenSharing` is frontmost.
- Carbon Text Input Source Services select ABC or Zhuyin explicitly; toggling does not depend on macOS input-source shortcuts.
- A small pure state machine recognizes the ordered Command-then-Shift gesture and is unit tested independently of AppKit.
- A coordinator owns input-source synchronization and depends on protocols for local source selection and F17 emission, allowing deterministic unit tests.
- A borderless AppKit HUD captures E/C/Escape while active.
- `SMAppService.mainApp` registers the application as a login item.

## Constraints

- Initial deployment target: macOS 14.0.
- Xcode 26.1.1 and Swift 6.2.1.
- No third-party runtime dependencies.
- The app requires Accessibility/Input Monitoring permission to suppress and emit keyboard events.
- The remote Mac must map F17 to “Select the previous input source” and have only the intended ABC/Zhuyin pair in the switching cycle.
- A local-only tool cannot inspect the remote input-source state; the explicit resync HUD is the recovery path when an event is missed or the remote source changes independently.

## Migration from Karabiner

Keep Karabiner active until the utility passes manual end-to-end testing. During app testing, disable the existing “Screen Sharing: Caps Lock to F18” rule to prevent duplicate events. After successful testing, remove the Karabiner rule, remove the local F18 input-source shortcut, and optionally uninstall Karabiner. Keep the remote F17 shortcut.

## Success criteria

- Caps Lock switches both Macs between ABC and Zhuyin during Screen Sharing.
- Half-width uppercase English works in ABC with Shift.
- Chinese composition works in Zhuyin.
- Command-Shift-letter shortcuts do not open the resync HUD.
- The ordered modifier-only gesture opens the HUD, E/C aligns local state, and Escape cancels.
- Caps Lock remains unchanged outside Screen Sharing.
- The app starts after login when enabled.
