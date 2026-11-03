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
        // IOHIDSetModifierLockState emits flagsChanged with keycode 255; clearing
        // the latch after a Caps press must not re-trigger a toggle.
        XCTAssertNil(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: []))
        XCTAssertNil(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: [.maskAlphaShift]))
    }
}
