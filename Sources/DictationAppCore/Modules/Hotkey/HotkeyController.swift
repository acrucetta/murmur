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

    public static func parse(identifier: String) -> HotkeyShortcut? {
#if canImport(Carbon)
        let normalized = identifier
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        let tokens = normalized.split(separator: "+").map(String.init)
        guard tokens.count >= 2 else {
            return nil
        }

        var modifiers: UInt32 = 0
        var keyCode: UInt32?

        for token in tokens {
            switch token {
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "opt", "option", "alt":
                modifiers |= UInt32(optionKey)
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            default:
                guard keyCode == nil, let parsedKeyCode = parseKeyCode(for: token) else {
                    return nil
                }
                keyCode = parsedKeyCode
            }
        }

        guard modifiers != 0, let keyCode else {
            return nil
        }

        return HotkeyShortcut(keyCode: keyCode, modifiers: modifiers)
#else
        return nil
#endif
    }

    public var identifier: String {
#if canImport(Carbon)
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("ctrl")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("shift")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("option")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("cmd")
        }
        parts.append(Self.keyToken(for: keyCode))
        return parts.joined(separator: "+")
#else
        return "key\(keyCode)"
#endif
    }

#if canImport(Carbon)
    private static func parseKeyCode(for token: String) -> UInt32? {
        if token.hasPrefix("key"), let parsed = UInt32(token.dropFirst(3)) {
            return parsed
        }

        switch token {
        case "space":
            return UInt32(kVK_Space)
        case "a":
            return UInt32(kVK_ANSI_A)
        case "b":
            return UInt32(kVK_ANSI_B)
        case "c":
            return UInt32(kVK_ANSI_C)
        case "d":
            return UInt32(kVK_ANSI_D)
        case "e":
            return UInt32(kVK_ANSI_E)
        case "f":
            return UInt32(kVK_ANSI_F)
        case "g":
            return UInt32(kVK_ANSI_G)
        case "h":
            return UInt32(kVK_ANSI_H)
        case "i":
            return UInt32(kVK_ANSI_I)
        case "j":
            return UInt32(kVK_ANSI_J)
        case "k":
            return UInt32(kVK_ANSI_K)
        case "l":
            return UInt32(kVK_ANSI_L)
        case "m":
            return UInt32(kVK_ANSI_M)
        case "n":
            return UInt32(kVK_ANSI_N)
        case "o":
            return UInt32(kVK_ANSI_O)
        case "p":
            return UInt32(kVK_ANSI_P)
        case "q":
            return UInt32(kVK_ANSI_Q)
        case "r":
            return UInt32(kVK_ANSI_R)
        case "s":
            return UInt32(kVK_ANSI_S)
        case "t":
            return UInt32(kVK_ANSI_T)
        case "u":
            return UInt32(kVK_ANSI_U)
        case "v":
            return UInt32(kVK_ANSI_V)
        case "w":
            return UInt32(kVK_ANSI_W)
        case "x":
            return UInt32(kVK_ANSI_X)
        case "y":
            return UInt32(kVK_ANSI_Y)
        case "z":
            return UInt32(kVK_ANSI_Z)
        case "0":
            return UInt32(kVK_ANSI_0)
        case "1":
            return UInt32(kVK_ANSI_1)
        case "2":
            return UInt32(kVK_ANSI_2)
        case "3":
            return UInt32(kVK_ANSI_3)
        case "4":
            return UInt32(kVK_ANSI_4)
        case "5":
            return UInt32(kVK_ANSI_5)
        case "6":
            return UInt32(kVK_ANSI_6)
        case "7":
            return UInt32(kVK_ANSI_7)
        case "8":
            return UInt32(kVK_ANSI_8)
        case "9":
            return UInt32(kVK_ANSI_9)
        default:
            return nil
        }
    }

    private static func keyToken(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space):
            return "space"
        case UInt32(kVK_ANSI_A):
            return "a"
        case UInt32(kVK_ANSI_B):
            return "b"
        case UInt32(kVK_ANSI_C):
            return "c"
        case UInt32(kVK_ANSI_D):
            return "d"
        case UInt32(kVK_ANSI_E):
            return "e"
        case UInt32(kVK_ANSI_F):
            return "f"
        case UInt32(kVK_ANSI_G):
            return "g"
        case UInt32(kVK_ANSI_H):
            return "h"
        case UInt32(kVK_ANSI_I):
            return "i"
        case UInt32(kVK_ANSI_J):
            return "j"
        case UInt32(kVK_ANSI_K):
            return "k"
        case UInt32(kVK_ANSI_L):
            return "l"
        case UInt32(kVK_ANSI_M):
            return "m"
        case UInt32(kVK_ANSI_N):
            return "n"
        case UInt32(kVK_ANSI_O):
            return "o"
        case UInt32(kVK_ANSI_P):
            return "p"
        case UInt32(kVK_ANSI_Q):
            return "q"
        case UInt32(kVK_ANSI_R):
            return "r"
        case UInt32(kVK_ANSI_S):
            return "s"
        case UInt32(kVK_ANSI_T):
            return "t"
        case UInt32(kVK_ANSI_U):
            return "u"
        case UInt32(kVK_ANSI_V):
            return "v"
        case UInt32(kVK_ANSI_W):
            return "w"
        case UInt32(kVK_ANSI_X):
            return "x"
        case UInt32(kVK_ANSI_Y):
            return "y"
        case UInt32(kVK_ANSI_Z):
            return "z"
        case UInt32(kVK_ANSI_0):
            return "0"
        case UInt32(kVK_ANSI_1):
            return "1"
        case UInt32(kVK_ANSI_2):
            return "2"
        case UInt32(kVK_ANSI_3):
            return "3"
        case UInt32(kVK_ANSI_4):
            return "4"
        case UInt32(kVK_ANSI_5):
            return "5"
        case UInt32(kVK_ANSI_6):
            return "6"
        case UInt32(kVK_ANSI_7):
            return "7"
        case UInt32(kVK_ANSI_8):
            return "8"
        case UInt32(kVK_ANSI_9):
            return "9"
        default:
            return "key\(keyCode)"
        }
    }
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
        shortcuts.map(\.identifier).joined(separator: "|")
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

    public init(shortcuts: [HotkeyShortcut] = [.defaultPushToTalk, .defaultBackupPushToTalk]) {}

    public convenience init(shortcut: HotkeyShortcut) {
        self.init(shortcuts: [shortcut])
    }

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
