import Testing
@testable import DictationAppCore

struct AppleScriptRecordingMediaControllerTests {
    @Test
    func pausesOnlyActivePlayersAndResumesOnlyThosePausedByController() {
        var pauseCalls: [String] = []
        var resumeCalls: [String] = []

        let controller = AppleScriptRecordingMediaController(
            logger: NoopLogger(),
            dispatchAsync: { work in work() },
            scriptRunner: { script in
                if script.contains("tell application \"Music\""),
                   script.contains("if player state is playing then")
                {
                    pauseCalls.append("music")
                    return "paused"
                }
                if script.contains("tell application \"Spotify\""),
                   script.contains("if player state is playing then")
                {
                    pauseCalls.append("spotify")
                    return "noop"
                }
                if script.contains("tell application \"Music\""),
                   script.contains("if player state is paused then")
                {
                    resumeCalls.append("music")
                    return "resumed"
                }
                if script.contains("tell application \"Spotify\""),
                   script.contains("if player state is paused then")
                {
                    resumeCalls.append("spotify")
                    return "resumed"
                }
                return "noop"
            }
        )

        controller.pauseMediaForRecording()
        controller.resumeMediaAfterRecording()

        #expect(pauseCalls == ["music", "spotify"])
        #expect(resumeCalls == ["music"])
    }
}

struct SwitchableRecordingMediaControllerTests {
    @Test
    func delegatesToCurrentControllerAndCanSwapAtRuntime() {
        let first = RecordingMediaSpy()
        let second = RecordingMediaSpy()
        let switchable = SwitchableRecordingMediaController(initialController: first)

        switchable.pauseMediaForRecording()
        switchable.resumeMediaAfterRecording()
        #expect(first.pauseCallCount == 1)
        #expect(first.resumeCallCount == 1)
        #expect(second.pauseCallCount == 0)
        #expect(second.resumeCallCount == 0)

        switchable.setController(second)
        switchable.pauseMediaForRecording()
        switchable.resumeMediaAfterRecording()

        #expect(first.pauseCallCount == 1)
        #expect(first.resumeCallCount == 1)
        #expect(second.pauseCallCount == 1)
        #expect(second.resumeCallCount == 1)
    }
}
