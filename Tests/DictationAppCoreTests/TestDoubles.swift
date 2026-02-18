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

final class FeedbackSpy: FeedbackPresenting {
    private(set) var recordingStartCount = 0
    private(set) var recordingStopCount = 0

    func recordingDidStart() {
        recordingStartCount += 1
    }

    func recordingDidStop() {
        recordingStopCount += 1
    }
}

final class RecordingMediaSpy: RecordingMediaControlling {
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0

    func pauseMediaForRecording() {
        pauseCallCount += 1
    }

    func resumeMediaAfterRecording() {
        resumeCallCount += 1
    }
}
