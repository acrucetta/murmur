import Foundation

public final class SwitchableRecordingMediaController: RecordingMediaControlling {
    private let queue = DispatchQueue(label: "murmur.recording.media.switchable")
    private var currentController: RecordingMediaControlling

    public init(initialController: RecordingMediaControlling) {
        currentController = initialController
    }

    public func setController(_ controller: RecordingMediaControlling) {
        queue.sync {
            currentController = controller
        }
    }

    public func pauseMediaForRecording() {
        queue.sync {
            currentController.pauseMediaForRecording()
        }
    }

    public func resumeMediaAfterRecording() {
        queue.sync {
            currentController.resumeMediaAfterRecording()
        }
    }
}
