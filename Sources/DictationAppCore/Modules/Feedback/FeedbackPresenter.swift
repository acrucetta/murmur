public protocol FeedbackPresenting {
    func recordingDidStart()
    func recordingDidStop()
}

public struct NoopFeedbackPresenter: FeedbackPresenting {
    public init() {}

    public func recordingDidStart() {}

    public func recordingDidStop() {}
}
