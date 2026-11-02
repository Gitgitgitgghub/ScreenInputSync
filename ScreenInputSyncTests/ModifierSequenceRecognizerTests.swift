import XCTest
@testable import ScreenInputSync

final class ModifierSequenceRecognizerTests: XCTestCase {
    func testCommandThenShiftTriggersAfterBothKeysAreReleased() {
        var recognizer = ModifierSequenceRecognizer()

        XCTAssertEqual(recognizer.handle(.commandDown), .pending)
        XCTAssertEqual(recognizer.handle(.shiftDown), .pending)
        XCTAssertEqual(recognizer.handle(.commandUp), .pending)
        XCTAssertEqual(recognizer.handle(.shiftUp), .triggered)
    }

    func testShiftFirstDoesNotStartSequence() {
        var recognizer = ModifierSequenceRecognizer()

        XCTAssertEqual(recognizer.handle(.shiftDown), .ignored)
        XCTAssertEqual(recognizer.handle(.commandDown), .ignored)
        XCTAssertEqual(recognizer.handle(.shiftUp), .ignored)
        XCTAssertEqual(recognizer.handle(.commandUp), .ignored)
    }

    func testOtherKeyCancelsPendingSequence() {
        var recognizer = ModifierSequenceRecognizer()

        XCTAssertEqual(recognizer.handle(.commandDown), .pending)
        XCTAssertEqual(recognizer.handle(.shiftDown), .pending)
        XCTAssertEqual(recognizer.handle(.otherKeyDown), .cancelled)
        XCTAssertEqual(recognizer.handle(.commandUp), .ignored)
        XCTAssertEqual(recognizer.handle(.shiftUp), .ignored)
    }

    func testCommandShiftLetterNeverTriggers() {
        var recognizer = ModifierSequenceRecognizer()

        _ = recognizer.handle(.commandDown)
        _ = recognizer.handle(.shiftDown)
        XCTAssertEqual(recognizer.handle(.otherKeyDown), .cancelled)
        XCTAssertEqual(recognizer.handle(.shiftUp), .ignored)
        XCTAssertEqual(recognizer.handle(.commandUp), .ignored)
    }

    func testResetClearsPendingSequence() {
        var recognizer = ModifierSequenceRecognizer()

        _ = recognizer.handle(.commandDown)
        _ = recognizer.handle(.shiftDown)
        XCTAssertEqual(recognizer.handle(.reset), .cancelled)
        XCTAssertEqual(recognizer.handle(.commandUp), .ignored)
        XCTAssertEqual(recognizer.handle(.shiftUp), .ignored)
    }
}
