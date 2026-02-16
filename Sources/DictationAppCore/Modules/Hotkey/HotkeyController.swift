import Foundation
#if canImport(Carbon)
import Carbon
#endif

public struct HotkeyShortcut: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

#if canImport(Carbon)
    public static let defaultPushToTalk = HotkeyShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey | optionKey)
    )
#else
    public static let defaultPushToTalk = HotkeyShortcut(keyCode: 49, modifiers: 0)
#endif
}

public protocol HotkeyControlling: AnyObject {
    var onPressed: ((ShortcutPressed) -> Void)? { get set }
    var onReleased: ((ShortcutReleased) -> Void)? { get set }
    func startListening() throws
    func stopListening()
}

public enum HotkeyControllerError: Error {
    case alreadyListening
    case registrationFailed(status: Int32)
}

#if canImport(Carbon)
public final class HotkeyController: HotkeyControlling {
    private static let signature: OSType = 0x4D55524D // "MURM"

    public var onPressed: ((ShortcutPressed) -> Void)?
    public var onReleased: ((ShortcutReleased) -> Void)?
    public private(set) var isListening = false

    private let shortcut: HotkeyShortcut
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventHandlerUPP: EventHandlerUPP?

    public init(shortcut: HotkeyShortcut = .defaultPushToTalk) {
        self.shortcut = shortcut
    }

    public func startListening() throws {
        guard !isListening else {
            throw HotkeyControllerError.alreadyListening
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let handlerUPP: EventHandlerUPP = { _, eventRef, userData in
            guard let userData, let eventRef else {
                return noErr
            }

            let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
            return controller.handleCarbonEvent(eventRef)
        }
        eventHandlerUPP = handlerUPP

        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerUPP,
            2,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            eventHandlerUPP = nil
            throw HotkeyControllerError.registrationFailed(status: installStatus)
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
            }
            self.eventHandlerRef = nil
            eventHandlerUPP = nil
            throw HotkeyControllerError.registrationFailed(status: registerStatus)
        }

        isListening = true
    }

    public func stopListening() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        eventHandlerUPP = nil
        isListening = false
    }

    public func simulatePress(at timestamp: Date = Date()) {
        guard isListening else {
            return
        }
        onPressed?(.init(timestamp: timestamp))
    }

    public func simulateRelease(at timestamp: Date = Date()) {
        guard isListening else {
            return
        }
        onReleased?(.init(timestamp: timestamp))
    }

    private func handleCarbonEvent(_ eventRef: EventRef) -> OSStatus {
        let eventKind = GetEventKind(eventRef)
        let now = Date()
        if eventKind == UInt32(kEventHotKeyPressed) {
            onPressed?(.init(timestamp: now))
        } else if eventKind == UInt32(kEventHotKeyReleased) {
            onReleased?(.init(timestamp: now))
        }
        return noErr
    }
}
#else
public final class HotkeyController: HotkeyControlling {
    public var onPressed: ((ShortcutPressed) -> Void)?
    public var onReleased: ((ShortcutReleased) -> Void)?
    public private(set) var isListening = false

    public init(shortcut: HotkeyShortcut = .defaultPushToTalk) {}

    public func startListening() throws {
        guard !isListening else {
            throw HotkeyControllerError.alreadyListening
        }
        isListening = true
    }

    public func stopListening() {
        isListening = false
    }

    public func simulatePress(at timestamp: Date = Date()) {
        guard isListening else { return }
        onPressed?(.init(timestamp: timestamp))
    }

    public func simulateRelease(at timestamp: Date = Date()) {
        guard isListening else { return }
        onReleased?(.init(timestamp: timestamp))
    }
}
#endif
