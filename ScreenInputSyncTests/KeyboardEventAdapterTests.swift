import CoreGraphics
import XCTest
@testable import ScreenInputSync

final class KeyboardEventAdapterTests: XCTestCase {
    func testCapsLockLatchOnIsPressAndLatchOffIsRelease() {
        // Observed on macOS 15: press reports latch on, release reports latch off.
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 57, flags: [.maskAlphaShift]),
            .capsLockPressed
        )
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 57, flags: []),
            .capsLockReleased
        )
    }

    func testSyntheticLockStateChangeIsNotTreatedAsCapsLockPress() {
        // Latch changes made by the system or IOHIDSetModifierLockState use
        // keycode 255; they must not count as another Caps Lock press.
        XCTAssertEqual(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: []), .lockStateChanged)
        XCTAssertEqual(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: [.maskAlphaShift]), .lockStateChanged)
    }

    func testOtherModifiersMakeTheChordACombination() {
        // Pressing Control, Option, fn or Caps Lock.
        for keyCode: Int64 in [57, 58, 59, 61, 62, 63] {
            XCTAssertTrue(KeyboardEventAdapter.involvesOtherModifier(keyCode: keyCode, flags: []), "\(keyCode)")
        }
        // Command or Shift pressed while Control, Option or fn is already held.
        for flags: CGEventFlags in [.maskControl, .maskAlternate, .maskSecondaryFn] {
            XCTAssertTrue(KeyboardEventAdapter.involvesOtherModifier(keyCode: 55, flags: [.maskCommand, flags]))
        }
    }

    func testBareCommandShiftAndLockStateChangesAreNotOtherModifiers() {
        XCTAssertFalse(KeyboardEventAdapter.involvesOtherModifier(keyCode: 55, flags: [.maskCommand]))
        XCTAssertFalse(KeyboardEventAdapter.involvesOtherModifier(keyCode: 56, flags: [.maskCommand, .maskShift]))
        XCTAssertFalse(KeyboardEventAdapter.involvesOtherModifier(keyCode: 60, flags: [.maskShift, .maskAlphaShift]))
        XCTAssertFalse(KeyboardEventAdapter.involvesOtherModifier(keyCode: 255, flags: [.maskAlphaShift]))
    }
}
