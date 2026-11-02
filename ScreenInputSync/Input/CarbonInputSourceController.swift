import Carbon.HIToolbox
import Foundation

struct InputSourceDescriptor: Equatable {
    let sourceID: String
    let inputModeID: String?

    init(sourceID: String, inputModeID: String? = nil) {
        self.sourceID = sourceID
        self.inputModeID = inputModeID
    }
}

enum CarbonInputSourceError: Error, Equatable, LocalizedError {
    case currentSourceUnsupported(InputSourceDescriptor)
    case sourceNotAvailable(InputMode)
    case selectionFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .currentSourceUnsupported(descriptor):
            return "Current input source is not ABC or Zhuyin: \(descriptor.sourceID)"
        case let .sourceNotAvailable(mode):
            return "Required input source is not enabled: \(mode == .english ? "ABC" : "Traditional Zhuyin")"
        case let .selectionFailed(status):
            return "Unable to select input source (OSStatus \(status))"
        }
    }
}

enum InputSourceDescriptorMatcher {
    static func mode(for descriptor: InputSourceDescriptor) -> InputMode? {
        if descriptor.sourceID == "com.apple.keylayout.ABC" {
            return .english
        }
        if descriptor.inputModeID == "com.apple.inputmethod.TCIM.Zhuyin"
            || descriptor.sourceID == "com.apple.inputmethod.TCIM.Zhuyin"
            || descriptor.sourceID == "com.apple.keylayout.ZhuyinBopomofo" {
            return .chinese
        }
        return nil
    }

    static func requireDescriptor(
        for mode: InputMode,
        in descriptors: [InputSourceDescriptor]
    ) throws -> InputSourceDescriptor {
        guard let descriptor = descriptors.first(where: { self.mode(for: $0) == mode }) else {
            throw CarbonInputSourceError.sourceNotAvailable(mode)
        }
        return descriptor
    }
}

final class CarbonInputSourceController: InputSourceControlling {
    func currentMode() throws -> InputMode {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let descriptor = descriptor(for: source)
        guard let mode = InputSourceDescriptorMatcher.mode(for: descriptor) else {
            throw CarbonInputSourceError.currentSourceUnsupported(descriptor)
        }
        return mode
    }

    func select(_ mode: InputMode) throws {
        let sources = inputSources()
        let pairs = sources.map { (source: $0, descriptor: descriptor(for: $0)) }
        guard let pair = pairs.first(where: {
            InputSourceDescriptorMatcher.mode(for: $0.descriptor) == mode
        }) else {
            throw CarbonInputSourceError.sourceNotAvailable(mode)
        }

        let status = TISSelectInputSource(pair.source)
        guard status == noErr else {
            throw CarbonInputSourceError.selectionFailed(status)
        }
    }

    private func inputSources() -> [TISInputSource] {
        let list = TISCreateInputSourceList(nil, false).takeRetainedValue()
        return list as NSArray as? [TISInputSource] ?? []
    }

    private func descriptor(for source: TISInputSource) -> InputSourceDescriptor {
        InputSourceDescriptor(
            sourceID: stringProperty(source, key: kTISPropertyInputSourceID) ?? "unknown",
            inputModeID: stringProperty(source, key: kTISPropertyInputModeID)
        )
    }

    private func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
        guard let rawValue = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(rawValue).takeUnretainedValue() as String
    }
}
