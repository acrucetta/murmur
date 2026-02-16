import Foundation

public protocol HotkeyControlling {
    var onPressed: ((ShortcutPressed) -> Void)? { get set }
    var onReleased: ((ShortcutReleased) -> Void)? { get set }
    func startListening() throws
    func stopListening()
}

public enum HotkeyControllerError: Error {
    case alreadyListening
    case notListening
}

public final class HotkeyController: HotkeyControlling {
    public var onPressed: ((ShortcutPressed) -> Void)?
    public var onReleased: ((ShortcutReleased) -> Void)?
    public private(set) var isListening = false

    public init() {}

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
}
