import XCTest
@testable import ScreenInputSync

final class ModifierChordRecognizerTests: XCTestCase {
    func testCommandThenShiftTriggersAfterBothRelease() {
        var r = ModifierChordRecognizer()
        XCTAssertFalse(r.handle(.commandDown))
        XCTAssertFalse(r.handle(.shiftDown))
        XCTAssertFalse(r.handle(.commandUp))
        XCTAssertTrue(r.handle(.shiftUp))
    }

    func testShiftThenCommandAlsoTriggers() {
        var r = ModifierChordRecognizer()
        XCTAssertFalse(r.handle(.shiftDown))
        XCTAssertFalse(r.handle(.commandDown))
        XCTAssertFalse(r.handle(.shiftUp))
        XCTAssertTrue(r.handle(.commandUp))
    }

    func testCommandShiftLetterNeverTriggers() {
        var r = ModifierChordRecognizer()
        _ = r.handle(.commandDown)
        _ = r.handle(.shiftDown)
        _ = r.handle(.otherKeyDown)
        XCTAssertFalse(r.handle(.shiftUp))
        XCTAssertFalse(r.handle(.commandUp))
    }

    func testSingleModifierNeverTriggers() {
        var r = ModifierChordRecognizer()
        _ = r.handle(.commandDown)
        XCTAssertFalse(r.handle(.commandUp))
        _ = r.handle(.shiftDown)
        XCTAssertFalse(r.handle(.shiftUp))
    }

    func testRecognizerRearmsAfterInterruptedChord() {
        var r = ModifierChordRecognizer()
        _ = r.handle(.commandDown)
        _ = r.handle(.shiftDown)
        _ = r.handle(.otherKeyDown)
        _ = r.handle(.shiftUp)
        _ = r.handle(.commandUp)

        _ = r.handle(.commandDown)
        _ = r.handle(.shiftDown)
        _ = r.handle(.shiftUp)
        XCTAssertTrue(r.handle(.commandUp))
    }

    func testResetClearsPendingChord() {
        var r = ModifierChordRecognizer()
        _ = r.handle(.commandDown)
        _ = r.handle(.shiftDown)
        _ = r.handle(.reset)
        XCTAssertFalse(r.handle(.shiftUp))
        XCTAssertFalse(r.handle(.commandUp))
    }
}
