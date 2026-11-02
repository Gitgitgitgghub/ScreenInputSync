import XCTest
@testable import ScreenInputSync

final class InputSyncCoordinatorTests: XCTestCase {
    func testToggleBothSelectsOppositeModeThenEmitsOneRemoteToggle() {
        let source = SourceSpy(mode: .english)
        let remote = RemoteSpy()
        var reportedModes: [InputMode] = []
        let coordinator = InputSyncCoordinator(
            sourceController: source,
            remoteEmitter: remote,
            onModeChanged: { reportedModes.append($0) }
        )

        coordinator.toggleBoth()

        XCTAssertEqual(source.selectedModes, [.chinese])
        XCTAssertEqual(remote.emissionCount, 1)
        XCTAssertEqual(reportedModes, [.chinese])
    }

    func testAlignLocalSelectsRequestedModeWithoutRemoteToggle() {
        let source = SourceSpy(mode: .chinese)
        let remote = RemoteSpy()
        let coordinator = InputSyncCoordinator(sourceController: source, remoteEmitter: remote)

        coordinator.alignLocal(to: .english)

        XCTAssertEqual(source.selectedModes, [.english])
        XCTAssertEqual(remote.emissionCount, 0)
    }

    func testSourceErrorIsReportedAndRemoteIsNotToggled() {
        let source = SourceSpy(mode: .english)
        source.error = TestError.sourceUnavailable
        let remote = RemoteSpy()
        var errors: [Error] = []
        let coordinator = InputSyncCoordinator(
            sourceController: source,
            remoteEmitter: remote,
            onError: { errors.append($0) }
        )

        coordinator.toggleBoth()

        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(remote.emissionCount, 0)
    }
}

private enum TestError: Error {
    case sourceUnavailable
}

private final class SourceSpy: InputSourceControlling {
    private let mode: InputMode
    var error: Error?
    var selectedModes: [InputMode] = []

    init(mode: InputMode) {
        self.mode = mode
    }

    func currentMode() throws -> InputMode {
        if let error { throw error }
        return mode
    }

    func select(_ mode: InputMode) throws {
        if let error { throw error }
        selectedModes.append(mode)
    }
}

private final class RemoteSpy: RemoteToggleEmitting {
    var emissionCount = 0

    func emitRemoteToggle() {
        emissionCount += 1
    }
}
