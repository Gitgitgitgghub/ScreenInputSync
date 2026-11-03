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
        // The system clearing the latch emits flagsChanged with keycode 255;
        // it must not be counted as another Caps Lock press.
        XCTAssertNil(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: []))
        XCTAssertNil(KeyboardEventAdapter.map(type: .flagsChanged, keyCode: 255, flags: [.maskAlphaShift]))
    }
}
