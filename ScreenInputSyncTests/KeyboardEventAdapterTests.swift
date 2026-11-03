import CoreGraphics
import XCTest
@testable import ScreenInputSync

final class KeyboardEventAdapterTests: XCTestCase {
    func testCapsLockLatchedOnAndLatchedOffAreBothPhysicalPresses() {
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 57, flags: [.maskAlphaShift]),
            .capsLockPressed
        )
        XCTAssertEqual(
            KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 57, flags: []),
            .capsLockPressed
        )
    }

    func testSyntheticLockStateChangeIsNotTreatedAsCapsLockPress() {
        // IOHIDSetModifierLockState emits flagsChanged with keycode 255; clearing
        // the latch after a Caps press must not re-trigger a toggle.
        XCTAssertNil(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: []))
        XCTAssertNil(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: [.maskAlphaShift]))
    }
}
