import Foundation
import Testing
@testable import DictationAppCore

struct HotkeySessionBridgeTests {
    @Test
    func forwardsPressAndReleaseToSessionHandler() throws {
        let hotkey = HotkeyControllerFake()
        let session = SessionEventHandlerSpy()
        let bridge = HotkeySessionBridge(
            hotkeyController: hotkey,
            sessionEventHandler: session
        )

        try bridge.start()
        hotkey.emitPressed()
        hotkey.emitReleased()

        #expect(hotkey.startCallCount == 1)
        #expect(session.events.count == 2)
        #expect(session.events[0].isShortcutPressed)
        #expect(session.events[1].isShortcutReleased)
    }

    @Test
    func stopStopsHotkeyListener() throws {
        let hotkey = HotkeyControllerFake()
        let bridge = HotkeySessionBridge(
            hotkeyController: hotkey,
            sessionEventHandler: SessionEventHandlerSpy()
        )

        try bridge.start()
        bridge.stop()

        #expect(hotkey.stopCallCount == 1)
    }
}

private final class HotkeyControllerFake: HotkeyControlling {
    var onPressed: ((ShortcutPressed) -> Void)?
    var onReleased: ((ShortcutReleased) -> Void)?
    var startCallCount = 0
    var stopCallCount = 0

    func startListening() throws {
        startCallCount += 1
    }

    func stopListening() {
        stopCallCount += 1
    }

    func emitPressed() {
        onPressed?(.init(timestamp: Date()))
    }

    func emitReleased() {
        onReleased?(.init(timestamp: Date()))
    }
}

private final class SessionEventHandlerSpy: SessionEventHandling {
    private(set) var events: [SessionEvent] = []

    func handle(_ event: SessionEvent) {
        events.append(event)
    }
}

private extension SessionEvent {
    var isShortcutPressed: Bool {
        if case .shortcutPressed = self {
            return true
        }
        return false
    }

    var isShortcutReleased: Bool {
        if case .shortcutReleased = self {
            return true
        }
        return false
    }
}
