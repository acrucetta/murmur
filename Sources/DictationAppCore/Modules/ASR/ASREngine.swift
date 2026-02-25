public protocol ASREngining {
    var providesFinalTranscriptOnStop: Bool { get }
    func start()
    func consume(_ frame: AudioFrame)
    func stopAndFinalize() -> FinalTranscript?
}

public protocol ASREngineErrorReporting {
    var lastEngineErrorDescription: String? { get }
}

public protocol ASRWAVTranscribing {
    func transcribeWAVFile(at path: String) -> FinalTranscript?
}

public protocol ASREngineLifecycle {
    func shutdown()
}

public extension ASREngining {
    var providesFinalTranscriptOnStop: Bool { false }
}

public extension ASREngineLifecycle {
    func shutdown() {}
}

public final class ASREngine: ASREngining {
    public private(set) var isRunning = false
    public private(set) var consumedFrameCount = 0

    public init() {}

    public func start() {
        isRunning = true
        consumedFrameCount = 0
    }

    public func consume(_ frame: AudioFrame) {
        guard isRunning else {
            return
        }
        consumedFrameCount += 1
    }

    public func stopAndFinalize() -> FinalTranscript? {
        isRunning = false
        return nil
    }
}
