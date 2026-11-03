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
}
