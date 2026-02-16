import Foundation
#if canImport(Carbon)
import Carbon
#endif
#if canImport(CoreGraphics)
import CoreGraphics
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
        modifiers: UInt32(controlKey | shiftKey)
    )
    public static let defaultBackupPushToTalk = HotkeyShortcut(
        keyCode: UInt32(kVK_ANSI_D),
        modifiers: UInt32(controlKey | shiftKey)
    )
#else
    public static let defaultPushToTalk = HotkeyShortcut(keyCode: 49, modifiers: 0)
    public static let defaultBackupPushToTalk = HotkeyShortcut(keyCode: 2, modifiers: 0)
#endif

#if canImport(CoreGraphics)
    func matchesCGEvent(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        guard UInt32(keyCode) == self.keyCode else {
            return false
        }
        return normalizedRelevantFlags(flags) == normalizedRelevantFlags(expectedCGFlags())
    }

    private func expectedCGFlags() -> CGEventFlags {
        var flags: CGEventFlags = []
#if canImport(Carbon)
        if modifiers & UInt32(controlKey) != 0 {
            flags.insert(.maskControl)
        }
        if modifiers & UInt32(shiftKey) != 0 {
            flags.insert(.maskShift)
        }
        if modifiers & UInt32(optionKey) != 0 {
            flags.insert(.maskAlternate)
        }
        if modifiers & UInt32(cmdKey) != 0 {
            flags.insert(.maskCommand)
        }
#endif
        return flags
    }

    private func normalizedRelevantFlags(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskControl, .maskShift, .maskAlternate, .maskCommand])
    }
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

extension HotkeyControllerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyListening:
            return "hotkey listener already started"
        case .registrationFailed(let status):
            return "hotkey registration failed (\(HotkeyControllerError.statusLabel(for: status)))"
        }
    }

    private static func statusLabel(for status: Int32) -> String {
#if canImport(Carbon)
        switch status {
        case Int32(eventInternalErr):
            return "eventInternalErr:-9868"
        case Int32(eventHotKeyExistsErr):
            return "eventHotKeyExistsErr:-9878"
        case Int32(eventHotKeyInvalidErr):
            return "eventHotKeyInvalidErr:-9879"
        default:
            return "osstatus:\(status)"
        }
#else
        return "osstatus:\(status)"
#endif
    }
}

#if canImport(Carbon)
public final class HotkeyController: HotkeyControlling {
    private static let signature: OSType = 0x4D55524D // "MURM"
#if canImport(CoreGraphics)
    private static let monitoredEventMask: CGEventMask = {
        let keyDownMask = (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue))
        let keyUpMask = (CGEventMask(1) << CGEventMask(CGEventType.keyUp.rawValue))
        return keyDownMask | keyUpMask
    }()
#endif

    public var onPressed: ((ShortcutPressed) -> Void)?
    public var onReleased: ((ShortcutReleased) -> Void)?
    public private(set) var isListening = false
    public private(set) var activeBackends: [String] = []

    private let shortcuts: [HotkeyShortcut]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var eventHandlerUPP: EventHandlerUPP?
#if canImport(CoreGraphics)
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
#endif
    private var isShortcutDown = false

    public init(
        shortcuts: [HotkeyShortcut] = [.defaultPushToTalk, .defaultBackupPushToTalk]
    ) {
        self.shortcuts = shortcuts.isEmpty ? [.defaultPushToTalk] : shortcuts
    }

    public convenience init(shortcut: HotkeyShortcut) {
        self.init(shortcuts: [shortcut])
    }

    public func startListening() throws {
        guard !isListening else {
            throw HotkeyControllerError.alreadyListening
        }

#if canImport(Carbon)
        var registrationStatus = Int32(eventInternalErr)
#else
        var registrationStatus: Int32 = -1
#endif
        let hasCarbonBackend = startCarbonHotkeys(lastStatus: &registrationStatus)
        let hasEventTapBackend = startEventTap()

        guard hasCarbonBackend || hasEventTapBackend else {
            cleanupBackends()
            throw HotkeyControllerError.registrationFailed(status: registrationStatus)
        }

        activeBackends = []
        if hasCarbonBackend {
            activeBackends.append("carbon")
        }
        if hasEventTapBackend {
            activeBackends.append("event_tap")
        }

        isListening = true
    }

    public func stopListening() {
        cleanupBackends()
        activeBackends.removeAll()
        isShortcutDown = false
        isListening = false
    }

    public var backendSummary: String {
        if activeBackends.isEmpty {
            return "none"
        }
        return activeBackends.joined(separator: "+")
    }

    public var shortcutSummary: String {
        shortcuts.map { shortcutDescription($0) }.joined(separator: "|")
    }

    public func simulatePress(at timestamp: Date = Date()) {
        guard isListening else {
            return
        }
        emitPressedIfNeeded(timestamp: timestamp)
    }

    public func simulateRelease(at timestamp: Date = Date()) {
        guard isListening else {
            return
        }
        emitReleasedIfNeeded(timestamp: timestamp)
    }

    private func startCarbonHotkeys(lastStatus: inout Int32) -> Bool {
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
            GetApplicationEventTarget(),
            handlerUPP,
            2,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            eventHandlerUPP = nil
            lastStatus = installStatus
            return false
        }

        var registeredCount = 0
        for (index, shortcut) in shortcuts.enumerated() {
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            var hotKeyRef: EventHotKeyRef?
            let registerStatus = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if registerStatus == noErr, let hotKeyRef {
                hotKeyRefs.append(hotKeyRef)
                registeredCount += 1
            } else {
                lastStatus = registerStatus
            }
        }

        guard registeredCount > 0 else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
            }
            self.eventHandlerRef = nil
            eventHandlerUPP = nil
            return false
        }

        return true
    }

    private func handleCarbonEvent(_ eventRef: EventRef) -> OSStatus {
        let eventKind = GetEventKind(eventRef)
        let now = Date()
        if eventKind == UInt32(kEventHotKeyPressed) {
            emitPressedIfNeeded(timestamp: now)
        } else if eventKind == UInt32(kEventHotKeyReleased) {
            emitReleasedIfNeeded(timestamp: now)
        }
        return noErr
    }

    private func startEventTap() -> Bool {
#if canImport(CoreGraphics)
        let callback: CGEventTapCallBack = { _, type, event, userData in
            guard let userData else {
                return Unmanaged.passUnretained(event)
            }

            let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
            controller.handleEventTap(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.monitoredEventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventTapSource = source
        return true
#else
        return false
#endif
    }

#if canImport(CoreGraphics)
    private func handleEventTap(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            if shortcuts.contains(where: { $0.matchesCGEvent(keyCode: keyCode, flags: flags) }) {
                emitPressedIfNeeded(timestamp: Date())
            }
        case .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if shortcuts.contains(where: { $0.keyCode == UInt32(keyCode) }) {
                emitReleasedIfNeeded(timestamp: Date())
            }
        default:
            break
        }
    }
#endif

    private func cleanupBackends() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        eventHandlerUPP = nil

#if canImport(CoreGraphics)
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTapSource = nil
        eventTap = nil
#endif
    }

    private func shortcutDescription(_ shortcut: HotkeyShortcut) -> String {
        let key: String
        switch shortcut.keyCode {
        case UInt32(kVK_Space):
            key = "space"
        case UInt32(kVK_ANSI_D):
            key = "d"
        default:
            key = "key\(shortcut.keyCode)"
        }

        var parts: [String] = []
        if shortcut.modifiers & UInt32(controlKey) != 0 {
            parts.append("ctrl")
        }
        if shortcut.modifiers & UInt32(shiftKey) != 0 {
            parts.append("shift")
        }
        if shortcut.modifiers & UInt32(optionKey) != 0 {
            parts.append("option")
        }
        if shortcut.modifiers & UInt32(cmdKey) != 0 {
            parts.append("cmd")
        }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    private func emitPressedIfNeeded(timestamp: Date) {
        guard !isShortcutDown else {
            return
        }
        isShortcutDown = true
        onPressed?(.init(timestamp: timestamp))
    }

    private func emitReleasedIfNeeded(timestamp: Date) {
        guard isShortcutDown else {
            return
        }
        isShortcutDown = false
        onReleased?(.init(timestamp: timestamp))
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
