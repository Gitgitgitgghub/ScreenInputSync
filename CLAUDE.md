# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 語言

對話與回覆一律使用繁體中文。程式碼、程式註解與 commit message 維持英文。

## What this is

A macOS 14+ menu bar app (Swift 6, AppKit, no third-party dependencies, no SwiftPM) installed on the Mac that *initiates* an Apple Screen Sharing session. While `com.apple.ScreenSharing` is frontmost it makes Caps Lock / the user's input-switch shortcut flip both the local and remote input source (ABC ↔ Traditional Zhuyin). Outside Screen Sharing every key passes through untouched. User-facing docs (README, CHANGELOG, UI strings) are in Traditional Chinese; code and comments are in English.

The design rationale is in `docs/superpowers/specs/2026-11-02-screen-input-sync-design.md`. The key fact everything rests on: Screen Sharing converts keystrokes through the **local** input source before sending them, so local and remote must always match, and the Caps Lock lock state must never reach the remote (it puts remote Zhuyin into English mode).

## Commands

```bash
# Build + run all unit tests (unsigned build is fine for tests)
xcodebuild test -scheme ScreenInputSync -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Run a single test class or method
xcodebuild test -scheme ScreenInputSync -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  -only-testing:ScreenInputSyncTests/KeyboardActionRouterTests/testShiftFirstChordAlsoShowsHUD

# Reset Accessibility permission after a signing-identity change
tccutil reset Accessibility com.brant.ScreenInputSync
```

There is no linter. The app bails out of `applicationDidFinishLaunching` when `XCTestConfigurationFilePath` is set, so tests never install event taps.

## Architecture

Keyboard pipeline (all on the main run loop):

`EventTapController` (active `CGEventTap` at `.cgSessionEventTap`) → `KeyboardEventAdapter.map` (raw keycode/flags → `KeyboardEvent`) → `KeyboardActionRouter.route` (pure state machine → `RoutingDecision`) → `ScreenInputSyncAppDelegate.handle` → `InputSyncCoordinator` / `ResyncHUDController`.

- `KeyboardActionRouter` and `ModifierChordRecognizer` are pure value types and hold all key-handling logic; put new behavior there so it is unit-testable. `EventTapController` only translates events, strips `maskAlphaShift` when Screen Sharing is frontmost, and drops events whose decision `suppressesEvent`.
- The ⌘⇧ resync chord must be bare: anything else between pressing and releasing ⌘/⇧ cancels it. `KeyboardEventAdapter.involvesOtherModifier` catches ⌃/⌥/fn/Caps Lock (calls `router.interruptChord()`), and `EventTapController` compares the HID system's key-down/click counters (`CGEventSource.counterForEventType`) between chord start and release. The counters are needed because system hotkeys such as ⌘⇧4 swallow the key before the session tap sees it; they are read on demand, so no extra tap is needed.
- Input-switch shortcuts are read from `com.apple.symbolichotkeys` (IDs 60/61) by `SystemInputSwitchShortcuts` and reloaded each time Screen Sharing becomes frontmost. When the shortcut is pressed with modifiers held, the toggle is deferred until all modifiers are released (`modifiersReleased`), so the remote gets a bare F17; an even number of presses cancels out.
- `InputSyncCoordinator` owns the *tracked* remote mode (the remote cannot be queried). It enforces that mode locally while in Screen Sharing (including re-applying after `kTISNotifySelectedKeyboardInputSourceChanged`), and restores the user's previous source on leaving. `toggleBoth` selects the opposite source locally and emits F17; `alignLocal` (resync HUD, `E`/`C`) changes only the local side and never emits F17.
- The remote is switched by posting F17 (`F17RemoteToggleEmitter`), which the user binds on the remote to "Select the previous input source". F17 is used because anything the app posts is processed locally first; `⌃Space` would switch the local Mac too.
- Side effects sit behind protocols (`InputSourceControlling`, `RemoteToggleEmitting`, `FrontmostApplicationChecking`, `CapsLockStateResetting`) so tests use fakes. `HIDCapsLockStateController` clears the local Caps Lock latch via `IOHIDSetModifierLockState`.
- Startup: `ApplicationMover` relaunches from /Applications when the app runs translocated (Gatekeeper); `LoginItemController` wraps `SMAppService.mainApp`.

## Constraints

- Only the **Accessibility** permission is required (active tap + posting F17); the project deliberately avoids needing Input Monitoring. Check this before adding any new tap type.
- Ad-hoc signed builds are treated as a new app on each rebuild and lose the Accessibility grant; use a stable Development team when running the real app.
- Versioning is `major.minor`: `CFBundleShortVersionString` in `ScreenInputSync/Resources/Info.plist`, with `CFBundleVersion` incremented by 1. Each release gets a CHANGELOG entry (Traditional Chinese), a `vX.Y` tag and a GitHub Release with `ScreenInputSync-X.Y.zip`, a universal Release build signed with the same Apple Development certificate as before (a different certificate invalidates users' Accessibility grant). Commit messages use conventional prefixes (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `build:`).
