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
        let controller = LoginItemController(service: service) {
            reportedErrors.append($0)
        }

        controller.enableIfNeeded()

        XCTAssertEqual(reportedErrors.count, 1)
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
