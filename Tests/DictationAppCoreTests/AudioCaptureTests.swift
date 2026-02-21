import Testing
@testable import DictationAppCore

struct AudioCaptureTests {
    @Test
    func forwardsEmittedFramesToHandler() {
        let capture = AudioCapture()
        var received: [AudioFrame] = []
        capture.onFrame = { frame in
            received.append(frame)
        }

        let frame = AudioFrame(samples: [0.1, -0.1], sampleRate: 16_000, channels: 1)
        capture.emitFrame(frame)

        #expect(received == [frame])
    }

    @Test
    func audioCaptureErrorHasActionableDescriptions() {
        let missing = AudioCaptureError.inputDeviceNotFound("Mic-1")
        let failedSet = AudioCaptureError.failedToSetInputDevice(-50)

        #expect(missing.localizedDescription.contains("preferred input device not found"))
        #expect(missing.localizedDescription.contains("Mic-1"))
        #expect(failedSet.localizedDescription.contains("osstatus:-50"))
    }
}
