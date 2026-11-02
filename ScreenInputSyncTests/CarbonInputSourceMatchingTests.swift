import XCTest
@testable import ScreenInputSync

final class CarbonInputSourceMatchingTests: XCTestCase {
    func testMatchesABCSourceIdentifier() {
        let descriptor = InputSourceDescriptor(sourceID: "com.apple.keylayout.ABC")
        XCTAssertEqual(InputSourceDescriptorMatcher.mode(for: descriptor), .english)
    }

    func testMatchesTraditionalZhuyinInputModeIdentifier() {
        let descriptor = InputSourceDescriptor(
            sourceID: "com.apple.inputmethod.TCIM",
            inputModeID: "com.apple.inputmethod.TCIM.Zhuyin"
        )
        XCTAssertEqual(InputSourceDescriptorMatcher.mode(for: descriptor), .chinese)
    }

    func testMatchesEnabledZhuyinKeyboardLayoutFallback() {
        let descriptor = InputSourceDescriptor(sourceID: "com.apple.keylayout.ZhuyinBopomofo")
        XCTAssertEqual(InputSourceDescriptorMatcher.mode(for: descriptor), .chinese)
    }

    func testDoesNotMatchUnrelatedSource() {
        let descriptor = InputSourceDescriptor(sourceID: "com.apple.keylayout.USInternational-PC")
        XCTAssertNil(InputSourceDescriptorMatcher.mode(for: descriptor))
    }

    func testMissingRequestedModeProducesDescriptiveError() {
        let descriptors = [InputSourceDescriptor(sourceID: "com.apple.keylayout.ABC")]

        XCTAssertThrowsError(
            try InputSourceDescriptorMatcher.requireDescriptor(for: .chinese, in: descriptors)
        ) { error in
            XCTAssertEqual(
                error as? CarbonInputSourceError,
                .sourceNotAvailable(.chinese)
            )
        }
    }
}
