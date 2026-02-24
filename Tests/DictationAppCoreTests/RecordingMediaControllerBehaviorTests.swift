import Testing
@testable import DictationAppCore

struct AppleScriptRecordingMediaControllerTests {
    @Test
    func volumeOnlyModeDoesNotSendAppOrBrowserPauseScripts() {
        var sawAppOrBrowserControlScript = false

        let controller = AppleScriptRecordingMediaController(
            logger: NoopLogger(),
            dispatchAsync: { work in work() },
            scriptRunner: { script in
                if script.contains("tell application \"Music\"")
                    || script.contains("tell application \"Spotify\"")
                    || script.contains("tell application \"Google Chrome\"")
                    || script.contains("tell application \"Arc\"")
                    || script.contains("tell application \"Safari\"")
                {
                    sawAppOrBrowserControlScript = true
                }
                if script.contains("output volume of (get volume settings)") { return "37|false" }
                if script.contains("set volume output volume 0") { return "muted" }
                if script.contains("set volume output volume 37 output muted false") { return "restored" }
                return "noop"
            }
        )

        controller.pauseMediaForRecording()
        controller.resumeMediaAfterRecording()

        #expect(sawAppOrBrowserControlScript == false)
    }

    @Test
    func mutesSystemVolumeDuringRecordingAndRestoresAfter() {
        var sawMuteCommand = false
        var sawRestoreCommand = false

        let controller = AppleScriptRecordingMediaController(
            logger: NoopLogger(),
            dispatchAsync: { work in work() },
            scriptRunner: { script in
                if script.contains("output volume of (get volume settings)") {
                    return "37|false"
                }
                if script.contains("set volume output volume 0") {
                    sawMuteCommand = true
                    return "muted"
                }
                if script.contains("set volume output volume 37 output muted false") {
                    sawRestoreCommand = true
                    return "restored"
                }
                return "noop"
            }
        )

        controller.pauseMediaForRecording()
        controller.resumeMediaAfterRecording()

        #expect(sawMuteCommand == true)
        #expect(sawRestoreCommand == true)
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
