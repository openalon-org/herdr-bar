import AppKit
import Carbon
import HerdrCore

/// Global shortcut via Carbon `RegisterEventHotKey`. No Accessibility prompt —
/// same API as the old system-wide hotkeys.
@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x48524452), id: 1)

    func apply(_ spec: HotkeySpec?) {
        unregister()
        guard let spec else { return }
        _ = register(spec)
    }

    @discardableResult
    func register(_ spec: HotkeySpec) -> Bool {
        unregister()
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else { return false }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    fileprivate func fire() {
        onPressed?()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyCallback,
            1,
            &spec,
            nil,
            &ref
        )
        if status == noErr {
            handlerRef = ref
        }
    }
}

private func carbonHotkeyCallback(
    _ _: EventHandlerCallRef?,
    _ event: EventRef?,
    _ _: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let err = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard err == noErr, hotKeyID.signature == OSType(0x48524452) else { return noErr }
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            HotkeyCenter.shared.fire()
        }
    } else {
        DispatchQueue.main.async {
            HotkeyCenter.shared.fire()
        }
    }
    return noErr
}
