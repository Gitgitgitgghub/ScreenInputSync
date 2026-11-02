import ServiceManagement

enum LoginItemStatus: Equatable {
    case enabled
    case requiresApproval
    case notRegistered
    case notFound
}

protocol LoginItemServicing: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

final class MainAppLoginItemService: LoginItemServicing {
    private let service = SMAppService.mainApp

    var status: LoginItemStatus {
        switch service.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .notRegistered
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}

final class LoginItemController {
    private let service: LoginItemServicing
    private let onError: (Error) -> Void

    init(
        service: LoginItemServicing = MainAppLoginItemService(),
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.service = service
        self.onError = onError
    }

    var status: LoginItemStatus { service.status }
    var isEnabled: Bool { service.status == .enabled }

    func enableIfNeeded() {
        guard service.status == .notRegistered else { return }
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                guard service.status != .enabled else { return }
                try service.register()
            } else {
                guard service.status != .notRegistered else { return }
                try service.unregister()
            }
        } catch {
            onError(error)
        }
    }
}
