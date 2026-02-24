import Foundation
import Testing
@testable import DictationAppCore

struct GenericProcessASREngineTests {
    @Test
    func returnsTranscriptFromRunnerOutput() {
        var capturedExecutable: String?
        var capturedArguments: [String] = []

        let engine = GenericProcessASREngine(
            command: ["python3", "scripts/transcribe_generic.py"],
            model: "qwen3-asr-1.7b",
            runCommand: { executable, arguments in
                capturedExecutable = executable
                capturedArguments = arguments
                return "generic transcript\n"
            }
        )

        engine.start()
        engine.consume(.init(samples: [0.11, -0.08, 0.03], sampleRate: 16_000, channels: 1))
        let result = engine.stopAndFinalize()

        #expect(result?.text == "generic transcript")
        #expect(capturedExecutable == "python3")
        #expect(capturedArguments.contains("scripts/transcribe_generic.py"))
        #expect(capturedArguments.contains("--model"))
        #expect(capturedArguments.contains("qwen3-asr-1.7b"))
        #expect(capturedArguments.contains { $0.hasSuffix(".wav") })
    }

    @Test
    func returnsNilWhenNoAudioWasProvided() {
        let engine = GenericProcessASREngine(
            command: ["python3", "scripts/transcribe_generic.py"],
            model: "qwen3-asr-1.7b"
        )
        engine.start()

        let result = engine.stopAndFinalize()

        #expect(result == nil)
        #expect(engine.lastError == .missingAudio)
    }

    @Test
    func transcribeWAVUsesGenericArguments() {
        var capturedArguments: [String] = []
        let engine = GenericProcessASREngine(
            command: ["python3", "scripts/transcribe_generic.py"],
            model: "parakeet-v3",
            runCommand: { _, arguments in
                capturedArguments = arguments
                return "wav transcript"
            }
        )

        let result = engine.transcribeWAVFile(at: "/tmp/sample.wav")

        #expect(result?.text == "wav transcript")
        #expect(capturedArguments == ["scripts/transcribe_generic.py", "/tmp/sample.wav", "--model", "parakeet-v3"])
    }
}
