public protocol RecordingMediaControlling {
    func pauseMediaForRecording()
    func resumeMediaAfterRecording()
}

public struct NoopRecordingMediaController: RecordingMediaControlling {
    public init() {}

    public func pauseMediaForRecording() {}

    public func resumeMediaAfterRecording() {}
}
