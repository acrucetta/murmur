public protocol StatusPresenting {
    func update(state: SessionState)
    func showPermissionPrompt(_ snapshot: PermissionSnapshot)
    func showError(_ error: FailureCode)
    func showPartialTranscript(_ text: String)
}

public final class StatusUIModel: StatusPresenting {
    public private(set) var currentState: SessionState = .idle
    public private(set) var lastPermissionPrompt: PermissionSnapshot?
    public private(set) var lastError: FailureCode?
    public private(set) var lastPartialTranscript: String?

    public init() {}

    public func update(state: SessionState) {
        currentState = state
    }

    public func showPermissionPrompt(_ snapshot: PermissionSnapshot) {
        lastPermissionPrompt = snapshot
    }

    public func showError(_ error: FailureCode) {
        lastError = error
    }

    public func showPartialTranscript(_ text: String) {
        lastPartialTranscript = text
    }
}
