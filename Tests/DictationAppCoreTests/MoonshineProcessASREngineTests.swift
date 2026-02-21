import Foundation
import Testing
@testable import DictationAppCore

struct MoonshineProcessASREngineTests {
    @Test
    func returnsTranscriptFromRunnerOutput() throws {
        var capturedExecutable: String?
        var capturedArguments: [String] = []

        let engine = MoonshineProcessASREngine(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            model: "moonshine/tiny",
            runCommand: { executable, arguments in
                capturedExecutable = executable
                capturedArguments = arguments
                return "transcribed text\n"
            }
        )

        engine.start()
        engine.consume(.init(samples: [0.1, -0.2, 0.3], sampleRate: 16_000, channels: 1))
        let result = engine.stopAndFinalize()

        #expect(result?.text == "transcribed text")
        #expect(capturedExecutable == "python3")
        #expect(capturedArguments.contains("scripts/moonshine_transcribe.py"))
        #expect(capturedArguments.contains("--model"))
        #expect(capturedArguments.contains("moonshine/tiny"))
        #expect(capturedArguments.contains("--offline"))
        #expect(capturedArguments.contains { $0.hasSuffix(".wav") })
    }

    @Test
    func returnsNilWhenNoAudioWasProvided() {
        let engine = MoonshineProcessASREngine(command: ["python3", "scripts/moonshine_transcribe.py"])
        engine.start()

        let result = engine.stopAndFinalize()
        #expect(result == nil)
    }
}
