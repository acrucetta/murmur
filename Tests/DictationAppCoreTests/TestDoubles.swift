@testable import DictationAppCore

final class StatusUISpy: StatusPresenting {
    private(set) var lastState: SessionState?
    private(set) var lastPermissionPrompt: PermissionSnapshot?
    private(set) var lastError: FailureCode?
    private(set) var partialTranscripts: [String] = []

    func update(state: SessionState) {
        lastState = state
    }

    func showPermissionPrompt(_ snapshot: PermissionSnapshot) {
        lastPermissionPrompt = snapshot
    }

    func showError(_ error: FailureCode) {
        lastError = error
    }

    func showPartialTranscript(_ text: String) {
        partialTranscripts.append(text)
    }
}
