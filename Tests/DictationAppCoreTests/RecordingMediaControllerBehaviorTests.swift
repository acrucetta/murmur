import XCTest
@testable import DictationAppCore

final class AppleScriptRecordingMediaControllerTests: XCTestCase {
    func testVolumeOnlyModeDoesNotSendAppOrBrowserPauseScripts() {
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

        XCTAssertEqual(sawAppOrBrowserControlScript, false)
    }

    func testMutesSystemVolumeDuringRecordingAndRestoresAfter() {
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

        XCTAssertEqual(sawMuteCommand, true)
        XCTAssertEqual(sawRestoreCommand, true)
    }
}

final class SwitchableRecordingMediaControllerTests: XCTestCase {
    private class RecordingMediaSpy: RecordingMediaControlling {
        var pauseCallCount = 0
        var resumeCallCount = 0

        func pauseMediaForRecording() {
            pauseCallCount += 1
        }

        func resumeMediaAfterRecording() {
            resumeCallCount += 1
        }
    }

    func testDelegatesToCurrentControllerAndCanSwapAtRuntime() {
        let first = RecordingMediaSpy()
        let second = RecordingMediaSpy()
        let switchable = SwitchableRecordingMediaController(initialController: first)

        switchable.pauseMediaForRecording()
        switchable.resumeMediaAfterRecording()
        XCTAssertEqual(first.pauseCallCount, 1)
        XCTAssertEqual(first.resumeCallCount, 1)
        XCTAssertEqual(second.pauseCallCount, 0)
        XCTAssertEqual(second.resumeCallCount, 0)

        switchable.setController(second)
        switchable.pauseMediaForRecording()
        switchable.resumeMediaAfterRecording()

        XCTAssertEqual(first.pauseCallCount, 1)
        XCTAssertEqual(first.resumeCallCount, 1)
        XCTAssertEqual(second.pauseCallCount, 1)
        XCTAssertEqual(second.resumeCallCount, 1)
    }
}
