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

    @Test
    func pausesAndResumesBrowserPlaybackWhenMediaElementIsActive() {
        var pauseCalls: [String] = []
        var resumeCalls: [String] = []
        var resumeContainsYouTubeFallback = false

        let controller = AppleScriptRecordingMediaController(
            logger: NoopLogger(),
            dispatchAsync: { work in work() },
            scriptRunner: { script in
                if script.contains("tell application \"Google Chrome\""),
                   script.contains("media.pause()")
                {
                    pauseCalls.append("chrome")
                    return "paused"
                }
                if script.contains("tell application \"Google Chrome\""),
                   script.contains("media.play()")
                {
                    resumeCalls.append("chrome")
                    resumeContainsYouTubeFallback = script.contains("ytp-play-button")
                    return "resumed"
                }
                return "noop"
            }
        )

        controller.pauseMediaForRecording()
        controller.resumeMediaAfterRecording()

        #expect(pauseCalls == ["chrome"])
        #expect(resumeCalls == ["chrome"])
        #expect(resumeContainsYouTubeFallback == true)
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
