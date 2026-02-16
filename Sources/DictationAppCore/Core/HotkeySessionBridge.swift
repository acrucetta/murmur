import Foundation

public protocol SessionEventHandling {
    func handle(_ event: SessionEvent)
}

extension SessionOrchestrator: SessionEventHandling {}

public final class HotkeySessionBridge {
    private let hotkeyController: HotkeyControlling
    private let sessionEventHandler: SessionEventHandling

    public init(
        hotkeyController: HotkeyControlling,
        sessionEventHandler: SessionEventHandling
    ) {
        self.hotkeyController = hotkeyController
        self.sessionEventHandler = sessionEventHandler
    }

    public func start() throws {
        hotkeyController.onPressed = { [weak self] pressed in
            self?.sessionEventHandler.handle(.shortcutPressed(pressed))
        }
        hotkeyController.onReleased = { [weak self] released in
            self?.sessionEventHandler.handle(.shortcutReleased(released))
        }
        try hotkeyController.startListening()
    }

    public func stop() {
        hotkeyController.stopListening()
    }
}
