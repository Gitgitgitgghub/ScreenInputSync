import XCTest
@testable import ScreenInputSync

final class InputSyncCoordinatorTests: XCTestCase {
    func testToggleBothFlipsLocalThenEmitsOneRemoteToggle() {
        let source = SourceSpy(mode: .english)
        let remote = RemoteSpy()
        var reported: [InputMode] = []
        let coordinator = InputSyncCoordinator(
            sourceController: source, remoteEmitter: remote,
            onModeChanged: { reported.append($0) }
        )
        coordinator.screenSharingDidBecomeFrontmost()

        coordinator.toggleBoth()

        XCTAssertEqual(source.mode, .chinese)
        XCTAssertEqual(remote.emissionCount, 1)
        XCTAssertEqual(reported, [.chinese])
        XCTAssertEqual(coordinator.remoteMode, .chinese)
    }

    func testToggleUsesTrackedRemoteModeEvenIfLocalWasChangedBySystem() {
        let source = SourceSpy(mode: .english)
        let coordinator = InputSyncCoordinator(sourceController: source, remoteEmitter: RemoteSpy())
        coordinator.screenSharingDidBecomeFrontmost()

        source.mode = .chinese   // e.g. system Caps Lock ABC switch raced ahead
        coordinator.toggleBoth()

        XCTAssertEqual(source.mode, .chinese)
        XCTAssertEqual(coordinator.remoteMode, .chinese)
    }

    func testLocalChangeInsideScreenSharingIsForcedBackToRemoteMode() {
        let source = SourceSpy(mode: .chinese)
        let coordinator = InputSyncCoordinator(sourceController: source, remoteEmitter: RemoteSpy())
        coordinator.screenSharingDidBecomeFrontmost()

        source.mode = .english
        coordinator.localSourceDidChange()

        XCTAssertEqual(source.mode, .chinese)
    }

    func testLocalChangeOutsideScreenSharingIsLeftAlone() {
        let source = SourceSpy(mode: .chinese)
        let coordinator = InputSyncCoordinator(sourceController: source, remoteEmitter: RemoteSpy())

        source.mode = .english
        coordinator.localSourceDidChange()

        XCTAssertEqual(source.selectedModes, [])
    }

    func testLeavingRestoresLocalModeAndReturningReappliesRemoteMode() {
        let source = SourceSpy(mode: .english)
        let coordinator = InputSyncCoordinator(sourceController: source, remoteEmitter: RemoteSpy())
        coordinator.screenSharingDidBecomeFrontmost()
        coordinator.toggleBoth()                 // both now Chinese
        coordinator.screenSharingDidResignFrontmost()
        XCTAssertEqual(source.mode, .english, "local preference restored outside Screen Sharing")

        coordinator.screenSharingDidBecomeFrontmost()
        XCTAssertEqual(source.mode, .chinese, "local must match the remote again")
    }

    func testAlignLocalSetsRemoteModeWithoutRemoteToggle() {
        let source = SourceSpy(mode: .chinese)
        let remote = RemoteSpy()
        let coordinator = InputSyncCoordinator(sourceController: source, remoteEmitter: remote)
        coordinator.screenSharingDidBecomeFrontmost()

        XCTAssertTrue(coordinator.alignLocal(to: .english))

        XCTAssertEqual(source.mode, .english)
        XCTAssertEqual(coordinator.remoteMode, .english)
        XCTAssertEqual(remote.emissionCount, 0)
    }

    func testFailedAlignmentReturnsFalse() {
        let source = SourceSpy(mode: .english)
        source.error = TestError.sourceUnavailable
        let coordinator = InputSyncCoordinator(sourceController: source, remoteEmitter: RemoteSpy())

        XCTAssertFalse(coordinator.alignLocal(to: .chinese))
    }

    func testSourceErrorIsReportedAndRemoteIsNotToggled() {
        let source = SourceSpy(mode: .english)
        source.error = TestError.sourceUnavailable
        let remote = RemoteSpy()
        var errors: [Error] = []
        let coordinator = InputSyncCoordinator(
            sourceController: source, remoteEmitter: remote,
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
    var mode: InputMode
    var error: Error?
    var selectedModes: [InputMode] = []

    init(mode: InputMode) { self.mode = mode }

    func currentMode() throws -> InputMode {
        if let error { throw error }
        return mode
    }

    func select(_ mode: InputMode) throws {
        if let error { throw error }
        selectedModes.append(mode)
        self.mode = mode
    }
}

private final class RemoteSpy: RemoteToggleEmitting {
    var emissionCount = 0
    func emitRemoteToggle() { emissionCount += 1 }
}
