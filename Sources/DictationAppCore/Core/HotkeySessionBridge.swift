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
    public var toggleMode: Bool
    private var isRecording = false

    public init(
        hotkeyController: HotkeyControlling,
        sessionEventHandler: SessionEventHandling,
        toggleMode: Bool = false,
        onForwardedEvent: ((ForwardedEvent) -> Void)? = nil
    ) {
        self.hotkeyController = hotkeyController
        self.sessionEventHandler = sessionEventHandler
        self.toggleMode = toggleMode
        self.onForwardedEvent = onForwardedEvent
    }

    public func start() throws {
        hotkeyController.onPressed = { [weak self] pressed in
            guard let self else { return }
            if toggleMode {
                if isRecording {
                    isRecording = false
                    onForwardedEvent?(.released)
                    sessionEventHandler.handle(.shortcutReleased(.init(timestamp: pressed.timestamp)))
                } else {
                    isRecording = true
                    onForwardedEvent?(.pressed)
                    sessionEventHandler.handle(.shortcutPressed(pressed))
                }
            } else {
                onForwardedEvent?(.pressed)
                sessionEventHandler.handle(.shortcutPressed(pressed))
            }
        }
        hotkeyController.onReleased = { [weak self] released in
            guard let self else { return }
            if toggleMode {
                return
            }
            onForwardedEvent?(.released)
            sessionEventHandler.handle(.shortcutReleased(released))
        }
        try hotkeyController.startListening()
    }

    public func stop() {
        hotkeyController.stopListening()
    }

    public func resetToggleState() {
        isRecording = false
    }
}
