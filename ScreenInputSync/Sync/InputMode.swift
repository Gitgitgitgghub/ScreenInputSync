enum InputMode: Equatable {
    case english
    case chinese

    var opposite: InputMode {
        self == .english ? .chinese : .english
    }
}

protocol InputSourceControlling {
    func currentMode() throws -> InputMode
    func select(_ mode: InputMode) throws
}

protocol RemoteToggleEmitting {
    func emitRemoteToggle()
}
