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

protocol LoginItemPreferenceStoring: AnyObject {
    var userChoice: Bool? { get set }
}

final class UserDefaultsLoginItemPreferences: LoginItemPreferenceStoring {
    private let defaults: UserDefaults
    private let key = "launchAtLoginUserChoice"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var userChoice: Bool? {
        get {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.bool(forKey: key)
        }
        set {
            if let newValue { defaults.set(newValue, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
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
    private let preferences: LoginItemPreferenceStoring
    private let onError: (Error) -> Void

    init(
        service: LoginItemServicing = MainAppLoginItemService(),
        preferences: LoginItemPreferenceStoring = UserDefaultsLoginItemPreferences(),
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.service = service
        self.preferences = preferences
        self.onError = onError
    }

    var status: LoginItemStatus { service.status }
    var isEnabled: Bool { service.status == .enabled }

    func enableIfNeeded() {
        guard preferences.userChoice != false,
              service.status == .notRegistered else { return }
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        preferences.userChoice = enabled
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
