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
}
