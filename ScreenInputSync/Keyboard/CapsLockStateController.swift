import IOKit
import IOKit.hidsystem

protocol CapsLockStateResetting {
    /// Clears the HID Caps Lock latch. Suppressing the Caps Lock event in an
    /// event tap does not undo the latch, so later keystrokes would otherwise
    /// carry `maskAlphaShift` into Screen Sharing.
    func clearCapsLock()
}

final class HIDCapsLockStateController: CapsLockStateResetting {
    private var connection: io_connect_t = 0

    init() {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDSystemClass)
        )
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var opened: io_connect_t = 0
        if IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &opened) == KERN_SUCCESS {
            connection = opened
        }
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    func clearCapsLock() {
        guard connection != 0 else { return }
        var isOn = false
        guard IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &isOn) == KERN_SUCCESS,
              isOn else { return }
        // The resulting synthetic flagsChanged event uses keycode 255, so the
        // keyboard adapter does not treat it as another Caps Lock press.
        _ = IOHIDSetModifierLockState(connection, Int32(kIOHIDCapsLockState), false)
    }
}
