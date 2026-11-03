# ScreenInputSync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-only macOS menu bar app that synchronizes ABC/Zhuyin input switching across Apple Screen Sharing and provides keyboard-only drift recovery.

**Architecture:** An AppKit app routes a conditional `CGEventTap` through pure gesture and synchronization components. Carbon TIS APIs select local sources explicitly, F17 is emitted to Screen Sharing, and an AppKit HUD handles resynchronization choices.

**Tech Stack:** Swift 6.2, AppKit, Carbon HIToolbox, CoreGraphics, ServiceManagement, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-02-screen-input-sync-design.md`

## Global Constraints

- Deployment target is macOS 14.0.
- Use Xcode 26.1.1 and Swift 6.2.1 compatibility.
- No third-party runtime dependencies.
- Recognize only Command-first, then Shift, with no intervening non-modifier key.
- Intercept Caps Lock and the resync gesture only while bundle ID `com.apple.ScreenSharing` is frontmost.
- Keep F17 as the remote input-source shortcut; do not depend on local F18.
- Do not remove Karabiner until end-to-end testing passes.

## Review Focus

- Command-Shift-letter shortcuts must cancel the gesture and pass through unchanged; pin in Task 2 tests.
- Shift-first then Command must not trigger the HUD; pin in Task 2 tests.
- Event-tap timeout/disable events must re-enable the tap; pin routing behavior in Task 4 and manually verify in Task 7.
- Missing ABC or Zhuyin sources must produce a visible menu error rather than silently changing the wrong source; pin in Task 3 tests.
- Resync E/C must never emit F17; pin in Task 3 tests.

---

### Task 1: Project shell and menu bar lifecycle

**Files:**
- Create: `project.yml`
- Create: `ScreenInputSync/App/ScreenInputSyncApp.swift`
- Create: `ScreenInputSync/App/MenuBarController.swift`
- Create: `ScreenInputSync/Resources/Info.plist`
- Create: `ScreenInputSyncTests/SmokeTests.swift`

**Interfaces:**
- Produces: `ScreenInputSyncAppDelegate`, `MenuBarController`, and a generated `ScreenInputSync.xcodeproj` with app and unit-test targets.

- [x] **Step 1: Write the failing smoke test**

Add `SmokeTests.testApplicationName()` asserting `AppMetadata.displayName == "ScreenInputSync"` before `AppMetadata` exists.

- [x] **Step 2: Generate the project and verify RED**

Run: `xcodegen generate && xcodebuild test -project ScreenInputSync.xcodeproj -scheme ScreenInputSync -destination 'platform=macOS' -only-testing:ScreenInputSyncTests/SmokeTests`
Expected: FAIL because `AppMetadata` is undefined.

- [x] **Step 3: Implement the minimal app shell**

Create `enum AppMetadata { static let displayName = "ScreenInputSync" }`, an `NSApplicationDelegate` entry point, and an `NSStatusItem` menu with disabled status text and Quit. Set `LSUIElement` to true in `Info.plist`.

- [x] **Step 4: Verify GREEN**

Run the Task 1 test command; expected PASS.

- [x] **Step 5: Commit**

Commit message: `feat: scaffold ScreenInputSync menu bar app`

### Task 2: Ordered modifier gesture recognizer

**Files:**
- Create: `ScreenInputSync/Keyboard/ModifierSequenceRecognizer.swift`
- Create: `ScreenInputSyncTests/ModifierSequenceRecognizerTests.swift`

**Interfaces:**
- Produces: `struct ModifierSequenceRecognizer` with `mutating func handle(_ event: ModifierSequenceEvent) -> ModifierSequenceResult`.
- Produces: `ModifierSequenceEvent` cases for commandDown, shiftDown, commandUp, shiftUp, otherKeyDown, and reset; result cases ignored, pending, triggered, and cancelled.

- [x] **Step 1: Write failing sequence tests**

Test Command-down → Shift-down → releases triggers only after both release; Shift-first is ignored; any other key cancels; Command-Shift-P never triggers; reset clears pending state.

- [x] **Step 2: Verify RED**

Run: `xcodebuild test -project ScreenInputSync.xcodeproj -scheme ScreenInputSync -destination 'platform=macOS' -only-testing:ScreenInputSyncTests/ModifierSequenceRecognizerTests`
Expected: FAIL because recognizer types do not exist.

- [x] **Step 3: Implement the state machine**

Implement `ModifierSequenceRecognizer` as a value type with private explicit states; do not use timers or AppKit.

- [x] **Step 4: Verify GREEN**

Run the Task 2 test command; expected all sequence tests PASS.

- [x] **Step 5: Commit**

Commit message: `feat: recognize ordered modifier resync gesture`

### Task 3: Input synchronization domain logic

**Files:**
- Create: `ScreenInputSync/Sync/InputMode.swift`
- Create: `ScreenInputSync/Sync/InputSyncCoordinator.swift`
- Create: `ScreenInputSyncTests/InputSyncCoordinatorTests.swift`

**Interfaces:**
- Produces: `enum InputMode { case english, chinese }`.
- Produces: `protocol InputSourceControlling` with `currentMode() throws -> InputMode` and `select(_ mode: InputMode) throws`.
- Produces: `protocol RemoteToggleEmitting` with `emitRemoteToggle()`.
- Produces: `InputSyncCoordinator.toggleBoth()` and `InputSyncCoordinator.alignLocal(to:)`.

- [x] **Step 1: Write failing coordinator tests**

Assert `toggleBoth()` selects the opposite local mode then emits exactly one remote toggle; `alignLocal(to:)` selects the requested local mode and emits none; source errors are surfaced through `onError`.

- [x] **Step 2: Verify RED**

Run the coordinator test class; expected FAIL because domain types do not exist.

- [x] **Step 3: Implement minimal coordinator logic**

Inject `InputSourceControlling`, `RemoteToggleEmitting`, `onModeChanged`, and `onError` closures. Keep AppKit and Carbon out of this file.

- [x] **Step 4: Verify GREEN**

Run the coordinator test class; expected PASS.

- [x] **Step 5: Commit**

Commit message: `feat: add deterministic input sync coordinator`

### Task 4: Keyboard event routing

**Files:**
- Create: `ScreenInputSync/Keyboard/KeyboardActionRouter.swift`
- Create: `ScreenInputSync/Keyboard/EventTapController.swift`
- Create: `ScreenInputSync/ScreenSharing/FrontmostApplicationChecking.swift`
- Create: `ScreenInputSyncTests/KeyboardActionRouterTests.swift`

**Interfaces:**
- Consumes: `ModifierSequenceRecognizer` and coordinator actions from Tasks 2–3.
- Produces: `KeyboardActionRouter.route(_:) -> RoutingDecision` with passThrough, suppress, toggleBoth, showResyncHUD, chooseEnglish, chooseChinese, and dismissHUD decisions.
- Produces: `EventTapController.start()`, `stop()`, and timeout re-enable handling.

- [x] **Step 1: Write failing routing tests**

Assert events pass outside Screen Sharing; Caps is suppressed and toggles inside it; the ordered modifier gesture is suppressed only once recognized; E/C/Escape are captured only while HUD is active; ordinary Command-Shift-letter shortcuts pass through; timeout resets state and requests tap re-enable.

- [x] **Step 2: Verify RED**

Run the router test class; expected FAIL because router types do not exist.

- [x] **Step 3: Implement the pure router**

Inject a frontmost-app boolean into each route call and expose explicit HUD-active state.

- [x] **Step 4: Implement the CGEvent adapter**

Map `flagsChanged`, keyDown, Caps Lock, E, C, and Escape into router events. Suppress only decisions that require suppression and re-enable the event tap after timeout/user disable callbacks.

- [x] **Step 5: Verify GREEN**

Run the router test class and full test suite; expected PASS.

- [x] **Step 6: Commit**

Commit message: `feat: route Screen Sharing keyboard events`

### Task 5: Carbon input sources and F17 emitter

**Files:**
- Create: `ScreenInputSync/Input/CarbonInputSourceController.swift`
- Create: `ScreenInputSync/Keyboard/F17RemoteToggleEmitter.swift`
- Create: `ScreenInputSyncTests/CarbonInputSourceMatchingTests.swift`

**Interfaces:**
- Consumes: protocols from Task 3.
- Produces: `CarbonInputSourceController: InputSourceControlling`.
- Produces: `F17RemoteToggleEmitter: RemoteToggleEmitting`.
- Produces: pure `InputSourceDescriptorMatcher.mode(for:)` used by unit tests.

- [x] **Step 1: Write failing descriptor matching tests**

Cover ABC ID, Traditional Zhuyin input-mode ID, unrelated sources, and missing configured sources. Assert missing sources yield a descriptive error.

- [x] **Step 2: Verify RED**

Run the matching test class; expected FAIL because matcher does not exist.

- [x] **Step 3: Implement Carbon source lookup and selection**

Use `TISCopyCurrentKeyboardInputSource`, `TISCreateInputSourceList`, and `TISSelectInputSource`. Match `com.apple.keylayout.ABC` and `com.apple.inputmethod.TCIM.Zhuyin` with a documented fallback for the enabled Traditional Zhuyin descriptor.

- [x] **Step 4: Implement F17 emission**

Post F17 key-down and key-up `CGEvent`s to the active session without modifiers.

- [x] **Step 5: Verify GREEN**

Run matching tests and full suite; expected PASS.

- [x] **Step 6: Commit**

Commit message: `feat: control local sources and emit remote toggle`

### Task 6: Resync HUD, permissions, and login item

**Files:**
- Create: `ScreenInputSync/UI/ResyncHUDController.swift`
- Create: `ScreenInputSync/Permissions/PermissionController.swift`
- Create: `ScreenInputSync/Startup/LoginItemController.swift`
- Create: `ScreenInputSyncTests/LoginItemControllerTests.swift`

**Interfaces:**
- Produces: `ResyncHUDController.show()`, `showConfirmation(_:)`, and `dismiss()`.
- Produces: `PermissionController.ensureAccessibilityPermission()`.
- Produces: `protocol LoginItemServicing` and `LoginItemController.enableIfNeeded()` backed by `SMAppService.mainApp`.

- [x] **Step 1: Write failing login-item tests**

Assert first launch registers when not registered, does nothing when enabled, and surfaces registration failure in menu status.

- [x] **Step 2: Verify RED**

Run the login-item test class; expected FAIL because controller types do not exist.

- [x] **Step 3: Implement login registration and permissions prompt**

Wrap `SMAppService.mainApp`; prompt through `AXIsProcessTrustedWithOptions` and expose missing-permission status.

- [x] **Step 4: Implement the HUD**

Use a nonactivating centered `NSPanel` showing `E  English`, `C  中文`, and `Esc  Cancel`; confirmation auto-dismisses after a short delay.

- [x] **Step 5: Wire menu, coordinator, event tap, and HUD in the app delegate**

Menu items: current mode/status, Resync, Launch at Login toggle, Quit. Start the event tap only after permission is available.

- [x] **Step 6: Verify GREEN**

Run login tests and full suite; expected PASS.

- [x] **Step 7: Commit**

Commit message: `feat: add resync HUD and login startup`

### Task 7: Packaging and end-to-end migration

**Files:**
- Create: `scripts/build-and-install.sh`
- Create: `README.md`

**Interfaces:**
- Produces: a signed local build installed at `/Applications/ScreenInputSync.app` and documented setup/removal steps.

- [x] **Step 1: Write the installation script checks**

Build Release with `xcodebuild`, copy the app to `/Applications`, ad-hoc sign when no development identity is configured, and relaunch it. Fail on any command error.

- [x] **Step 2: Build and run all automated verification**

Run: `xcodebuild test -project ScreenInputSync.xcodeproj -scheme ScreenInputSync -destination 'platform=macOS'`
Expected: all tests PASS with zero failures.

- [ ] **Step 3: Install and manually verify the approved workflow**

Verify permission prompt, automatic login registration, Caps outside Screen Sharing, Caps inside Screen Sharing, ABC uppercase `ABC`, Zhuyin composition, Command-Shift-P pass-through, ordered Command→Shift HUD, E/C alignment, Escape dismissal, and event-tap recovery after sleep/reconnect.

- [ ] **Step 4: Disable and remove the Karabiner rule only after Step 3 passes**

Back up then remove `Screen Sharing: Caps Lock to F18` from `~/.config/karabiner/karabiner.json`; remove local F18 shortcut; retain remote F17.

- [x] **Step 5: Document operations and rollback**

README must explain remote F17 setup, permissions, resync semantics, launch-at-login behavior, uninstall, and restoring the Karabiner backup.

- [x] **Step 6: Commit**

Commit message: `docs: add installation and migration guide`
