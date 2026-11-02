import XCTest
@testable import ScreenInputSync

final class SmokeTests: XCTestCase {
    func testApplicationName() {
        XCTAssertEqual(AppMetadata.displayName, "ScreenInputSync")
    }
}
