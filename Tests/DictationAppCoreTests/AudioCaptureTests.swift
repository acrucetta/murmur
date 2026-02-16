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
}
