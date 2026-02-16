public enum SessionState: Equatable, Sendable {
    case idle
    case listening
    case finalizing
    case inserting
    case error(FailureCode)
}

public struct StateMachine: Sendable {
    public init() {}

    public func nextState(from state: SessionState, event: SessionEvent) -> SessionState {
        switch (state, event) {
        case (.idle, .shortcutPressed):
            return .listening
        case (.listening, .shortcutReleased):
            return .finalizing
        case (.finalizing, .finalTranscript):
            return .inserting
        case (.inserting, .insertResult(let result)):
            if result.success {
                return .idle
            }
            return .error(result.error ?? .insertionFailed)
        case (.error, .reset):
            return .idle
        default:
            return state
        }
    }
}
