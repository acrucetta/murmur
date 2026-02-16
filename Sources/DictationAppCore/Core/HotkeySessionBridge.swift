import Foundation

public protocol SessionEventHandling {
    func handle(_ event: SessionEvent)
}

extension SessionOrchestrator: SessionEventHandling {}

public final class HotkeySessionBridge {
    public enum ForwardedEvent: Equatable {
        case pressed
        case released
    }

    private let hotkeyController: HotkeyControlling
    private let sessionEventHandler: SessionEventHandling
    private let onForwardedEvent: ((ForwardedEvent) -> Void)?

    public init(
        hotkeyController: HotkeyControlling,
        sessionEventHandler: SessionEventHandling,
        onForwardedEvent: ((ForwardedEvent) -> Void)? = nil
    ) {
        self.hotkeyController = hotkeyController
        self.sessionEventHandler = sessionEventHandler
        self.onForwardedEvent = onForwardedEvent
    }

    public func start() throws {
        hotkeyController.onPressed = { [weak self] pressed in
            self?.onForwardedEvent?(.pressed)
            self?.sessionEventHandler.handle(.shortcutPressed(pressed))
        }
        hotkeyController.onReleased = { [weak self] released in
            self?.onForwardedEvent?(.released)
            self?.sessionEventHandler.handle(.shortcutReleased(released))
        }
        try hotkeyController.startListening()
    }

    public func stop() {
        hotkeyController.stopListening()
    }
}
