import Foundation
import Testing
@testable import DictationAppCore

struct GenericProcessASREngineTests {
    final class WorkerStub: PersistentASRWorking {
        private(set) var transcribePaths: [String] = []
        private(set) var shutdownCallCount = 0
        var text = "worker transcript"

        func transcribe(wavPath: String) throws -> String {
            transcribePaths.append(wavPath)
            return text
        }

        func shutdown() {
            shutdownCallCount += 1
        }
    }

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
        var capturedArguments: [[String]] = []
        var activeModel = "parakeet-v3"
        let engine = GenericProcessASREngine(
            command: ["python3", "scripts/transcribe_generic.py"],
            model: "parakeet-v3",
            runCommand: { _, arguments in
                capturedArguments.append(arguments)
                return "wav transcript"
            },
            modelProvider: { activeModel }
        )

        let first = engine.transcribeWAVFile(at: "/tmp/sample.wav")
        activeModel = "parakeet-v4"
        let second = engine.transcribeWAVFile(at: "/tmp/sample2.wav")

        #expect(first?.text == "wav transcript")
        #expect(second?.text == "wav transcript")
        #expect(capturedArguments.count == 2)
        #expect(capturedArguments[0] == ["scripts/transcribe_generic.py", "/tmp/sample.wav", "--model", "parakeet-v3"])
        #expect(capturedArguments[1] == ["scripts/transcribe_generic.py", "/tmp/sample2.wav", "--model", "parakeet-v4"])
    }

    @Test
    func usesPersistentWorkerWhenServerFlagIsPresent() {
        let worker = WorkerStub()
        var runCommandCallCount = 0
        var capturedWorkerCommand: [String] = []
        let engine = GenericProcessASREngine(
            command: ["python3", "scripts/hf_asr_transcribe.py", "--server"],
            model: "mlx-community/Qwen3-ASR-0.6B-4bit",
            runCommand: { _, _ in
                runCommandCallCount += 1
                return ""
            },
            workerFactory: { command, _ in
                capturedWorkerCommand = command
                return worker
            }
        )

        let result = engine.transcribeWAVFile(at: "/tmp/sample.wav")

        #expect(result?.text == "worker transcript")
        #expect(worker.transcribePaths == ["/tmp/sample.wav"])
        #expect(capturedWorkerCommand.contains("--server"))
        #expect(capturedWorkerCommand == [
            "python3",
            "scripts/hf_asr_transcribe.py",
            "--server",
            "--model",
            "mlx-community/Qwen3-ASR-0.6B-4bit",
        ])
        #expect(runCommandCallCount == 0)

        engine.shutdown()
        #expect(worker.shutdownCallCount == 1)
    }

    @Test
    func usesExistingWorkerModelArgumentWhenAlreadyPresent() {
        let worker = WorkerStub()
        var capturedWorkerCommand: [String] = []
        let engine = GenericProcessASREngine(
            command: [
                "python3",
                "scripts/hf_asr_transcribe.py",
                "--server",
                "--model",
                "configured-model",
            ],
            model: "should-not-be-used",
            runCommand: { _, _ in "" },
            workerFactory: { command, _ in
                capturedWorkerCommand = command
                return worker
            }
        )

        _ = engine.transcribeWAVFile(at: "/tmp/sample.wav")

        #expect(capturedWorkerCommand == [
            "python3",
            "scripts/hf_asr_transcribe.py",
            "--server",
            "--model",
            "configured-model",
        ])
    }

    @Test
    func restartsPersistentWorkerWhenModelProviderChanges() {
        let firstWorker = WorkerStub()
        firstWorker.text = "first model"
        let secondWorker = WorkerStub()
        secondWorker.text = "second model"
        var workerCreateCount = 0
        var capturedWorkerCommands: [[String]] = []
        var configuredModel = "mlx-community/Qwen3-ASR-0.6B-4bit"

        let engine = GenericProcessASREngine(
            command: ["python3", "scripts/hf_asr_transcribe.py", "--server"],
            model: "fallback",
            runCommand: { _, _ in "" },
            workerFactory: { command, _ in
                capturedWorkerCommands.append(command)
                workerCreateCount += 1
                return workerCreateCount == 1 ? firstWorker : secondWorker
            },
            modelProvider: { configuredModel }
        )

        let first = engine.transcribeWAVFile(at: "/tmp/first.wav")
        configuredModel = "mlx-community/Qwen3-ASR-1.7B-4bit"
        let second = engine.transcribeWAVFile(at: "/tmp/second.wav")

        #expect(first?.text == "first model")
        #expect(second?.text == "second model")
        #expect(workerCreateCount == 2)
        #expect(firstWorker.shutdownCallCount == 1)
        #expect(secondWorker.shutdownCallCount == 0)
        #expect(capturedWorkerCommands == [
            [
                "python3",
                "scripts/hf_asr_transcribe.py",
                "--server",
                "--model",
                "mlx-community/Qwen3-ASR-0.6B-4bit",
            ],
            [
                "python3",
                "scripts/hf_asr_transcribe.py",
                "--server",
                "--model",
                "mlx-community/Qwen3-ASR-1.7B-4bit",
            ],
        ])
        #expect(firstWorker.transcribePaths == ["/tmp/first.wav"])
        #expect(secondWorker.transcribePaths == ["/tmp/second.wav"])
    }
}
