import Foundation
import DictationAppCore

@main
struct DictationPreviewCLI {
    static func main() {
        let args = Arguments.parse(CommandLine.arguments)
        switch args.mode {
        case .simulate(let transcript):
            runSimulatedPreview(transcript: transcript)
        case .moonshineWAV(let wavPath, let model, let pythonBinary, let scriptPath):
            runMoonshinePreview(wavPath: wavPath, model: model, pythonBinary: pythonBinary, scriptPath: scriptPath)
        case .moonshineLive(let model, let pythonBinary, let scriptPath):
            runMoonshineLivePreview(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath)
        case .invalid:
            print(Arguments.usage)
        }
    }

    private static func runSimulatedPreview(transcript: String) {
        let statusUI = ConsoleStatusUI()
        let writer = ConsoleFieldWriter()
        let logger = ConsoleLogger()

        let orchestrator = SessionOrchestrator(
            permissionManager: PermissionManager(initialSnapshot: .allGranted),
            audioCapture: AudioCapture(),
            asrEngine: ASREngine(),
            postProcessor: DeterministicTextPostProcessor(),
            fieldWriter: writer,
            statusUI: statusUI,
            logger: logger
        )

        print("Preview start")
        let pressedAt = Date()
        orchestrator.handle(.shortcutPressed(.init(timestamp: pressedAt)))

        orchestrator.handle(.audioFrame(.init(samples: [0.02, 0.07, -0.03], sampleRate: 16_000, channels: 1)))
        let partial = transcript.split(separator: " ").prefix(3).joined(separator: " ")
        if !partial.isEmpty {
            orchestrator.handle(.partialTranscript(.init(text: partial, confidence: nil)))
        }

        Thread.sleep(forTimeInterval: 0.15)
        let releasedAt = Date()
        orchestrator.handle(.shortcutReleased(.init(timestamp: releasedAt)))

        Thread.sleep(forTimeInterval: 0.22)
        orchestrator.handle(.finalTranscript(.init(text: transcript, confidence: 0.75)))

        print("Preview end")
        if let inserted = writer.lastInsertedText {
            print("inserted_text=\(inserted)")
        }
        for message in logger.messages {
            print("metric \(message)")
        }
    }

    private static func runMoonshinePreview(wavPath: String, model: String, pythonBinary: String, scriptPath: String) {
        let engine = MoonshineProcessASREngine(
            command: [pythonBinary, scriptPath],
            model: model
        )

        print("Moonshine preview start")
        if let final = engine.transcribeWAVFile(at: wavPath) {
            print("transcript=\(final.text)")
        } else {
            print("error=moonshine_transcription_failed")
            if let lastError = engine.lastError {
                print("details=\(lastError)")
            }
        }
        print("Moonshine preview end")
    }

    private static func runMoonshineLivePreview(model: String, pythonBinary: String, scriptPath: String) {
        let statusUI = ConsoleStatusUI()
        let writer = ConsoleFieldWriter()
        let logger = ConsoleLogger()
        let meter = LiveCaptureMeter()
        let audioCapture = AudioCapture()
        let asrEngine = MoonshineProcessASREngine(
            command: [pythonBinary, scriptPath],
            model: model
        )

        let orchestrator = SessionOrchestrator(
            permissionManager: PermissionManager(initialSnapshot: .allGranted),
            audioCapture: audioCapture,
            asrEngine: asrEngine,
            postProcessor: DeterministicTextPostProcessor(),
            fieldWriter: writer,
            statusUI: statusUI,
            logger: logger
        )

        audioCapture.onFrame = { frame in
            if let meterLine = meter.record(frame) {
                print(meterLine)
            }
            orchestrator.handle(.audioFrame(frame))
        }
        audioCapture.onError = { error in
            print("capture_error=\(error.localizedDescription)")
        }

        print("Moonshine live preview")
        print("Press Enter to start recording.")
        _ = readLine()
        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        print("Recording... Press Enter to stop.")
        _ = readLine()
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))
        print("capture_summary \(meter.summary())")

        if let inserted = writer.lastInsertedText {
            print("inserted_text=\(inserted)")
        } else {
            print("error=live_transcription_failed")
            if let lastError = asrEngine.lastError {
                print("details=\(lastError)")
            }
            if !meter.hasAudio {
                print("hint=no_audio_frames_captured_check_mic_permissions_input_device_or_speak_longer")
            }
        }

        for message in logger.messages {
            print("metric \(message)")
        }
    }
}

private struct Arguments {
    enum Mode {
        case simulate(String)
        case moonshineWAV(path: String, model: String, pythonBinary: String, scriptPath: String)
        case moonshineLive(model: String, pythonBinary: String, scriptPath: String)
        case invalid
    }

    static let usage = """
    Usage:
      swift run DictationPreviewCLI --simulate "hello world"
      swift run DictationPreviewCLI --moonshine-wav /path/audio.wav [--model moonshine/tiny] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
      swift run DictationPreviewCLI --moonshine-live [--model moonshine/tiny] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
    """

    let mode: Mode

    static func parse(_ rawArgs: [String]) -> Arguments {
        if let transcript = value(after: "--simulate", in: rawArgs) {
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return Arguments(mode: .simulate(trimmed))
            }
        }

        if let wavPath = value(after: "--moonshine-wav", in: rawArgs) {
            let model = value(after: "--model", in: rawArgs) ?? "moonshine/tiny"
            let pythonBinary = value(after: "--moonshine-python", in: rawArgs) ?? "python3"
            let scriptPath = value(after: "--moonshine-script", in: rawArgs) ?? "scripts/moonshine_transcribe.py"
            return Arguments(mode: .moonshineWAV(path: wavPath, model: model, pythonBinary: pythonBinary, scriptPath: scriptPath))
        }

        if rawArgs.contains("--moonshine-live") {
            let model = value(after: "--model", in: rawArgs) ?? "moonshine/tiny"
            let pythonBinary = value(after: "--moonshine-python", in: rawArgs) ?? "python3"
            let scriptPath = value(after: "--moonshine-script", in: rawArgs) ?? "scripts/moonshine_transcribe.py"
            return Arguments(mode: .moonshineLive(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath))
        }

        return Arguments(mode: .invalid)
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag) else {
            return nil
        }

        let next = args.index(after: index)
        guard next < args.endIndex else {
            return nil
        }

        return args[next]
    }
}

private final class ConsoleFieldWriter: FocusedFieldWriting {
    private(set) var lastInsertedText: String?

    func insert(_ text: String) -> InsertResult {
        lastInsertedText = text
        return .init(success: true, method: .accessibilityDirect, error: nil)
    }
}

private final class ConsoleStatusUI: StatusPresenting {
    func update(state: SessionState) {
        print("state=\(state)")
    }

    func showPermissionPrompt(_ snapshot: PermissionSnapshot) {
        print("permission_prompt=\(snapshot)")
    }

    func showError(_ error: FailureCode) {
        print("error=\(error.rawValue)")
    }

    func showPartialTranscript(_ text: String) {
        print("partial=\(text)")
    }
}

private final class ConsoleLogger: Logging {
    private(set) var messages: [String] = []

    func log(_ message: String) {
        messages.append(message)
    }
}

private final class LiveCaptureMeter {
    private let lock = NSLock()
    private var frameCount = 0
    private var sampleCount = 0
    private var rmsAccumulator: Double = 0
    private var peakRMS: Double = 0

    var hasAudio: Bool {
        lock.lock()
        defer { lock.unlock() }
        return sampleCount > 0
    }

    func record(_ frame: AudioFrame) -> String? {
        let frameRMS = rms(samples: frame.samples)

        lock.lock()
        frameCount += 1
        sampleCount += frame.samples.count
        rmsAccumulator += frameRMS
        peakRMS = max(peakRMS, frameRMS)
        let shouldPrint = frameCount % 25 == 0
        let summaryLine = meterLine(prefix: "input_meter")
        lock.unlock()

        return shouldPrint ? summaryLine : nil
    }

    func summary() -> String {
        lock.lock()
        defer { lock.unlock() }
        return meterLine(prefix: "stats")
    }

    private func meterLine(prefix: String) -> String {
        let avgRMS = frameCount > 0 ? rmsAccumulator / Double(frameCount) : 0
        return "\(prefix)=frames:\(frameCount) samples:\(sampleCount) avg_rms:\(String(format: "%.5f", avgRMS)) peak_rms:\(String(format: "%.5f", peakRMS))"
    }

    private func rms(samples: [Float]) -> Double {
        guard !samples.isEmpty else {
            return 0
        }

        var energy: Double = 0
        for sample in samples {
            let value = Double(sample)
            energy += value * value
        }

        return sqrt(energy / Double(samples.count))
    }
}
