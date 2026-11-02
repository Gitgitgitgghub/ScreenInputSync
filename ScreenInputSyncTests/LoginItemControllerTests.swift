import XCTest
@testable import ScreenInputSync

final class LoginItemControllerTests: XCTestCase {
    func testFirstLaunchRegistersWhenNotRegistered() {
        let service = LoginServiceSpy(status: .notRegistered)
        let controller = LoginItemController(service: service)

        controller.enableIfNeeded()

        XCTAssertEqual(service.registerCount, 1)
    }

    func testEnabledLoginItemDoesNothing() {
        let service = LoginServiceSpy(status: .enabled)
        let controller = LoginItemController(service: service)

        controller.enableIfNeeded()

        XCTAssertEqual(service.registerCount, 0)
    }

    func testRegistrationFailureIsSurfaced() {
        let service = LoginServiceSpy(status: .notRegistered)
        service.registerError = LoginTestError.denied
        var reportedErrors: [Error] = []
        let controller = LoginItemController(service: service, onError: {
            reportedErrors.append($0)
        })

        controller.enableIfNeeded()

        XCTAssertEqual(reportedErrors.count, 1)
    }

    func testExplicitOptOutPersistsAcrossManualRelaunch() {
        let preferences = LoginPreferenceSpy()
        let firstService = LoginServiceSpy(status: .enabled)
        let firstController = LoginItemController(service: firstService, preferences: preferences)
        firstController.setEnabled(false)

        let relaunchedService = LoginServiceSpy(status: .notRegistered)
        let relaunchedController = LoginItemController(service: relaunchedService, preferences: preferences)
        relaunchedController.enableIfNeeded()

        XCTAssertEqual(relaunchedService.registerCount, 0)
        XCTAssertEqual(preferences.userChoice, false)
    }

    func testPendingApprovalMenuSelectionOpensSettingsWithoutRegisteringAgain() {
        let service = LoginServiceSpy(status: .requiresApproval)
        var settingsOpenCount = 0
        let controller = LoginItemController(
            service: service,
            preferences: LoginPreferenceSpy(),
            openSettings: { settingsOpenCount += 1 }
        )

        controller.handleMenuSelection()

        XCTAssertEqual(settingsOpenCount, 1)
        XCTAssertEqual(service.registerCount, 0)
    }
}

private enum LoginTestError: Error { case denied }

private final class LoginServiceSpy: LoginItemServicing {
    var status: LoginItemStatus
    var registerCount = 0
    var unregisterCount = 0
    var registerError: Error?

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        status = .notRegistered
    }
}

private final class LoginPreferenceSpy: LoginItemPreferenceStoring {
    var userChoice: Bool?
}
