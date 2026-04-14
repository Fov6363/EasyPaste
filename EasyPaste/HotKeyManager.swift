import Carbon
import Foundation

final class HotKeyManager {
    private static let signature = OSType(0x45505354)

    private var configuration: ShortcutConfiguration
    private let handler: () -> Void
    private let hotKeyID = UInt32(1)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(configuration: ShortcutConfiguration, handler: @escaping () -> Void) {
        self.configuration = configuration
        self.handler = handler
        register()
    }

    deinit {
        unregister()
    }

    func update(configuration: ShortcutConfiguration) {
        guard self.configuration != configuration else { return }

        unregister()
        self.configuration = configuration
        register()
    }

    private func register() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )

        let carbonHotKeyID = EventHotKeyID(signature: Self.signature, id: hotKeyID)
        RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return noErr
        }

        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == HotKeyManager.signature,
              hotKeyID.id == manager.hotKeyID else {
            return noErr
        }

        manager.handler()
        return noErr
    }
}
