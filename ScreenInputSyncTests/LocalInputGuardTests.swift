import XCTest
@testable import ScreenInputSync

final class LocalInputGuardTests: XCTestCase {
    func testEnteringScreenSharingSwitchesLocalToABCAndLeavingRestoresIt() {
        let source = MutableSourceSpy(mode: .chinese)
        let guardian = LocalInputGuard(sourceController: source)

        guardian.screenSharingDidBecomeFrontmost()
        XCTAssertEqual(source.mode, .english)

        guardian.screenSharingDidResignFrontmost()
        XCTAssertEqual(source.mode, .chinese)
        XCTAssertEqual(source.selectedModes, [.english, .chinese])
    }

    func testLocalSwitchInsideScreenSharingIsForcedBackToABC() {
        let source = MutableSourceSpy(mode: .english)
        let guardian = LocalInputGuard(sourceController: source)
        guardian.screenSharingDidBecomeFrontmost()

        source.mode = .chinese
        guardian.localSourceDidChange()

        XCTAssertEqual(source.mode, .english)
    }

    func testLocalSwitchOutsideScreenSharingIsLeftAlone() {
        let source = MutableSourceSpy(mode: .english)
        let guardian = LocalInputGuard(sourceController: source)

        source.mode = .chinese
        guardian.localSourceDidChange()

        XCTAssertEqual(source.mode, .chinese)
        XCTAssertEqual(source.selectedModes, [])
    }

    func testRepeatedActivationKeepsOriginalModeForRestore() {
        let source = MutableSourceSpy(mode: .chinese)
        let guardian = LocalInputGuard(sourceController: source)

        guardian.screenSharingDidBecomeFrontmost()
        guardian.screenSharingDidBecomeFrontmost()
        guardian.screenSharingDidResignFrontmost()

        XCTAssertEqual(source.mode, .chinese)
    }

    func testAlreadyABCDoesNotReselect() {
        let source = MutableSourceSpy(mode: .english)
        let guardian = LocalInputGuard(sourceController: source)

        guardian.screenSharingDidBecomeFrontmost()
        guardian.screenSharingDidResignFrontmost()

        XCTAssertEqual(source.selectedModes, [])
    }
}

private final class MutableSourceSpy: InputSourceControlling {
    var mode: InputMode
    var selectedModes: [InputMode] = []

    init(mode: InputMode) { self.mode = mode }

    func currentMode() throws -> InputMode { mode }

    func select(_ mode: InputMode) throws {
        selectedModes.append(mode)
        self.mode = mode
    }
}
