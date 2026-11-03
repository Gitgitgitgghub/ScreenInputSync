import XCTest
@testable import ScreenInputSync

final class KeyboardActionRouterTests: XCTestCase {
    func testEventsPassThroughOutsideScreenSharing() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.capsLockPressed, screenSharingIsFrontmost: false), .passThrough)
        XCTAssertEqual(router.route(.commandDown, screenSharingIsFrontmost: false), .passThrough)
    }

    func testCapsLockPressPassesThroughAndTogglesRemoteOnceInsideScreenSharing() {
        var router = KeyboardActionRouter()
        let press = router.route(.capsLockPressed, screenSharingIsFrontmost: true)
        XCTAssertEqual(press, .toggleRemote)
        XCTAssertFalse(press.suppressesEvent, "Local system must still see Caps Lock to switch itself")
        XCTAssertEqual(router.route(.capsLockReleased, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.capsLockPressed, screenSharingIsFrontmost: true), .toggleRemote)
        XCTAssertEqual(router.route(.capsLockReleased, screenSharingIsFrontmost: true), .passThrough)
    }

    func testCapsLockReleasePassesThroughOutsideScreenSharing() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.capsLockReleased, screenSharingIsFrontmost: false), .passThrough)
    }

    func testOrderedGestureShowsHUDOnlyAfterBothModifiersRelease() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.commandDown, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.shiftDown, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.commandUp, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.shiftUp, screenSharingIsFrontmost: true), .showResyncHUD)
        XCTAssertFalse(RoutingDecision.showResyncHUD.suppressesEvent)
    }

    func testCommandShiftLetterCancelsAndPassesThrough() {
        var router = KeyboardActionRouter()
        _ = router.route(.commandDown, screenSharingIsFrontmost: true)
        _ = router.route(.shiftDown, screenSharingIsFrontmost: true)
        XCTAssertEqual(router.route(.otherKeyDown, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.shiftUp, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.commandUp, screenSharingIsFrontmost: true), .passThrough)
    }

    func testHUDCapturesChoicesAndEscape() {
        var router = KeyboardActionRouter()
        router.setHUDActive(true)
        XCTAssertEqual(router.route(.englishKeyDown, screenSharingIsFrontmost: true), .chooseEnglish)

        router.setHUDActive(true)
        XCTAssertEqual(router.route(.chineseKeyDown, screenSharingIsFrontmost: true), .chooseChinese)

        router.setHUDActive(true)
        XCTAssertEqual(router.route(.escapeKeyDown, screenSharingIsFrontmost: true), .dismissHUD)
    }

    func testHUDKeysPassWhenHUDIsInactive() {
        var router = KeyboardActionRouter()
        XCTAssertEqual(router.route(.englishKeyDown, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.chineseKeyDown, screenSharingIsFrontmost: true), .passThrough)
    }

    func testTapDisabledResetsPendingGestureAndRequestsReenable() {
        var router = KeyboardActionRouter()
        _ = router.route(.commandDown, screenSharingIsFrontmost: true)
        _ = router.route(.shiftDown, screenSharingIsFrontmost: true)

        XCTAssertEqual(router.route(.tapDisabled, screenSharingIsFrontmost: true), .reenableTap)
        XCTAssertEqual(router.route(.commandUp, screenSharingIsFrontmost: true), .passThrough)
        XCTAssertEqual(router.route(.shiftUp, screenSharingIsFrontmost: true), .passThrough)
    }

    func testFocusLossDismissesActiveHUDWithoutSuppressingEvent() {
        var router = KeyboardActionRouter()
        router.setHUDActive(true)

        let decision = router.route(.otherKeyDown, screenSharingIsFrontmost: false)

        XCTAssertEqual(decision, .dismissHUDPassingThrough)
        XCTAssertFalse(decision.suppressesEvent)
    }
}
