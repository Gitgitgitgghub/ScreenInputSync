import CoreGraphics
import XCTest
@testable import ScreenInputSync

final class InputSwitchShortcutTests: XCTestCase {
    private let controlSpace = InputSwitchShortcut(keyCode: 49, modifiers: [.maskControl])
    private let commandSpace = InputSwitchShortcut(keyCode: 49, modifiers: [.maskCommand])

    // MARK: - Reading System Settings

    func testMissingEntriesFallBackToMacOSDefaults() {
        XCTAssertEqual(SystemInputSwitchShortcuts.parse([:]), [
            controlSpace,
            InputSwitchShortcut(keyCode: 49, modifiers: [.maskControl, .maskAlternate]),
        ])
    }

    func testReadsCustomizedAndSkipsDisabledShortcuts() {
        // Same layout as `defaults export com.apple.symbolichotkeys`.
        let hotkeys: [String: Any] = [
            "60": ["enabled": true, "value": ["type": "standard", "parameters": [32, 49, 1_048_576]]],
            "61": ["enabled": false, "value": ["type": "standard", "parameters": [32, 49, 786_432]]],
        ]
        XCTAssertEqual(SystemInputSwitchShortcuts.parse(hotkeys), [commandSpace])
    }

    func testSkipsShortcutWithoutKey() {
        let hotkeys: [String: Any] = [
            "60": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 65535, 0]]],
            "61": ["enabled": false],
        ]
        XCTAssertEqual(SystemInputSwitchShortcuts.parse(hotkeys), [])
    }

    func testMatchesExactModifiersOnly() {
        XCTAssertTrue(controlSpace.matches(keyCode: 49, flags: [.maskControl]))
        XCTAssertTrue(controlSpace.matches(keyCode: 49, flags: [.maskControl, .maskAlphaShift]))
        XCTAssertFalse(controlSpace.matches(keyCode: 49, flags: [.maskControl, .maskShift]))
        XCTAssertFalse(controlSpace.matches(keyCode: 49, flags: []))
        XCTAssertFalse(controlSpace.matches(keyCode: 48, flags: [.maskControl]))
    }

    // MARK: - Mapping key events

    func testAdapterRecognizesShortcutPressRepeatAndRelease() {
        let shortcuts = [controlSpace]
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .keyDown, keyCode: 49, flags: [.maskControl], shortcuts: shortcuts),
            .inputSwitchShortcutPressed(modifiersHeld: true)
        )
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .keyDown, keyCode: 49, flags: [.maskControl], isAutorepeat: true, shortcuts: shortcuts),
            .inputSwitchShortcutRepeated
        )
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .keyUp, keyCode: 49, flags: [], shortcuts: shortcuts),
            .inputSwitchShortcutKeyUp
        )
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .keyDown, keyCode: 49, flags: [], shortcuts: shortcuts),
            .otherKeyDown,
            "A plain Space is ordinary typing"
        )
    }

    func testFunctionKeyShortcutWithoutModifiersSwitchesImmediately() {
        let f18 = InputSwitchShortcut(keyCode: 79, modifiers: [.maskSecondaryFn])
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .keyDown, keyCode: 79, flags: [.maskSecondaryFn], shortcuts: [f18]),
            .inputSwitchShortcutPressed(modifiersHeld: false)
        )
    }

    // MARK: - Routing

    func testShortcutSwitchesOnceModifiersAreReleased() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.inputSwitchShortcutPressed(modifiersHeld: true), screenSharingIsFrontmost: true), .suppress)
        XCTAssertEqual(router.route(.inputSwitchShortcutKeyUp, screenSharingIsFrontmost: true), .suppress)
        XCTAssertEqual(router.modifiersReleased(screenSharingIsFrontmost: true), .toggleBoth)
        XCTAssertEqual(router.modifiersReleased(screenSharingIsFrontmost: true), .passThrough)
    }

    func testPressingShortcutTwiceBeforeReleaseCancelsOut() {
        var router = KeyboardActionRouter()
        for _ in 0..<2 {
            _ = router.route(.inputSwitchShortcutPressed(modifiersHeld: true), screenSharingIsFrontmost: true)
            _ = router.route(.inputSwitchShortcutKeyUp, screenSharingIsFrontmost: true)
        }
        XCTAssertEqual(router.modifiersReleased(screenSharingIsFrontmost: true), .passThrough)
    }

    func testShortcutWithoutModifiersSwitchesImmediately() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.inputSwitchShortcutPressed(modifiersHeld: false), screenSharingIsFrontmost: true), .toggleBoth)
        XCTAssertEqual(router.modifiersReleased(screenSharingIsFrontmost: true), .passThrough)
    }

    func testShortcutPassesThroughOutsideScreenSharing() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.inputSwitchShortcutPressed(modifiersHeld: true), screenSharingIsFrontmost: false), .passThrough)
        XCTAssertEqual(router.route(.inputSwitchShortcutKeyUp, screenSharingIsFrontmost: false), .passThrough)
        XCTAssertEqual(router.modifiersReleased(screenSharingIsFrontmost: false), .passThrough)
    }

    func testSpaceKeyUpPassesWhenShortcutWasNotPressed() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.inputSwitchShortcutKeyUp, screenSharingIsFrontmost: true), .passThrough)
    }

    func testCommandSpaceDoesNotTriggerResyncChord() {
        var router = KeyboardActionRouter()
        _ = router.route(.commandDown, screenSharingIsFrontmost: true)
        _ = router.route(.inputSwitchShortcutPressed(modifiersHeld: true), screenSharingIsFrontmost: true)
        _ = router.route(.shiftDown, screenSharingIsFrontmost: true)
        _ = router.route(.shiftUp, screenSharingIsFrontmost: true)
        XCTAssertEqual(router.route(.commandUp, screenSharingIsFrontmost: true), .passThrough)
    }
}
