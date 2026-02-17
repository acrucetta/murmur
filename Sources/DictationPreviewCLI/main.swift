import Foundation
import DictationAppCore
#if canImport(Carbon)
import Carbon
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

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
        case .hotkeyDaemon(let model, let pythonBinary, let scriptPath):
            runHotkeyDaemon(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath)
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
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: statusUI,
            logger: logger
        )

        emit("Preview start")
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

        emit("Preview end")
        if let inserted = writer.lastInsertedText {
            emit("inserted_text=\(inserted)")
        }
        for message in logger.messages {
            emit("metric \(message)")
        }
    }

    private static func runMoonshinePreview(wavPath: String, model: String, pythonBinary: String, scriptPath: String) {
        let engine = MoonshineProcessASREngine(
            command: [pythonBinary, scriptPath],
            model: model
        )

        emit("Moonshine preview start")
        if let final = engine.transcribeWAVFile(at: wavPath) {
            emit("transcript=\(final.text)")
        } else {
            emit("error=moonshine_transcription_failed")
            if let lastError = engine.lastError {
                emit("details=\(lastError)")
            }
        }
        emit("Moonshine preview end")
    }

    private static func runMoonshineLivePreview(model: String, pythonBinary: String, scriptPath: String) {
        let statusUI = ConsoleStatusUI()
        let writer = RecordingFieldWriter(base: FocusedFieldWriter())
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
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: statusUI,
            logger: logger
        )

        audioCapture.onFrame = { frame in
            if let meterLine = meter.record(frame) {
                emit(meterLine)
            }
            orchestrator.handle(.audioFrame(frame))
        }
        audioCapture.onError = { error in
            emit("capture_error=\(error.localizedDescription)")
        }

        emit("Moonshine live preview")
        emit("Focus the target text field before starting.")
        emit("Press Enter to start recording.")
        _ = readLine()
        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        emit("Recording... Press Enter to stop.")
        _ = readLine()
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))
        emit("capture_summary \(meter.summary())")

        if let result = writer.lastResult, result.success {
            emit("insert_result=success method=\(result.method.rawValue)")
            if let inserted = writer.lastInsertedText {
                emit("inserted_text=\(inserted)")
            }
        } else {
            emit("error=live_transcription_failed")
            if let lastError = asrEngine.lastError {
                emit("details=\(lastError)")
            } else if let result = writer.lastResult {
                emit("details=insertion_failed method=\(result.method.rawValue) code=\(result.error?.rawValue ?? "unknown")")
            }
            if !meter.hasAudio {
                emit("hint=no_audio_frames_captured_check_mic_permissions_input_device_or_speak_longer")
            }
        }

        for message in logger.messages {
            emit("metric \(message)")
        }
    }

    private static func runHotkeyDaemon(model: String, pythonBinary: String, scriptPath: String) {
        let statusUI = ConsoleStatusUI()
        let logger = ConsoleLogger()
        logger.onLog = { message in
            emit("metric \(message)")
        }
        let writer = RecordingFieldWriter(base: FocusedFieldWriter()) { text, result in
            if result.success {
                emit("insert_result=success method=\(result.method.rawValue)")
                emit("inserted_text=\(text)")
            } else {
                emit("insert_result=failure method=\(result.method.rawValue) code=\(result.error?.rawValue ?? "unknown")")
            }
        }

        let audioCapture = AudioCapture()
        let asrEngine = MoonshineProcessASREngine(
            command: [pythonBinary, scriptPath],
            model: model
        )
        let orchestrator = SessionOrchestrator(
            permissionManager: PermissionManager(initialSnapshot: .allGranted),
            audioCapture: audioCapture,
            asrEngine: asrEngine,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: statusUI,
            logger: logger
        )
        statusUI.onError = { errorCode in
            guard errorCode == .engineError else {
                return
            }

            if let details = asrEngine.lastError {
                emit("details=\(details)")
                if case .missingAudio = details {
                    emit("hint=speak_while_holding_shortcut_and_verify_active_input_device")
                }
            }
        }

        audioCapture.onFrame = { frame in
            orchestrator.handle(.audioFrame(frame))
        }
        audioCapture.onError = { error in
            emit("capture_error=\(error.localizedDescription)")
        }

        let hotkeyController = HotkeyController()
        let bridge = HotkeySessionBridge(
            hotkeyController: hotkeyController,
            sessionEventHandler: orchestrator,
            onForwardedEvent: { event in
                switch event {
                case .pressed:
                    emit("hotkey_event=pressed")
                case .released:
                    emit("hotkey_event=released")
                }
            }
        )

        do {
            try bridge.start()
        } catch {
            emit("error=hotkey_start_failed details=\(error)")
            return
        }

        #if canImport(Carbon)
        emit("hotkey_daemon=running shortcuts=\(hotkeyController.shortcutSummary)")
        emit("hotkey_backend=\(hotkeyController.backendSummary)")
        if !hotkeyController.activeBackends.contains("event_tap") {
            emit("warning=event_tap_unavailable_check_input_monitoring_for_terminal_host")
        }
        if !hotkeyController.activeBackends.contains("carbon") {
            emit("warning=carbon_hotkey_unavailable_falling_back_to_event_tap")
        }
        #else
        emit("hotkey_daemon=running shortcuts=ctrl+shift+space|ctrl+shift+d")
        emit("hotkey_backend=none")
        #endif
        emit("hint=focus_any_textbox_hold_ctrl_shift_space_or_ctrl_shift_d_speak_release_to_insert")
#if canImport(Carbon)
        while true {
            _ = RunCurrentEventLoop(0.25)
        }
#else
        RunLoop.main.run()
#endif
    }
}

private struct Arguments {
    enum Mode {
        case simulate(String)
        case moonshineWAV(path: String, model: String, pythonBinary: String, scriptPath: String)
        case moonshineLive(model: String, pythonBinary: String, scriptPath: String)
        case hotkeyDaemon(model: String, pythonBinary: String, scriptPath: String)
        case invalid
    }

    static let usage = """
    Usage:
      swift run DictationPreviewCLI --simulate "hello world"
      swift run DictationPreviewCLI --moonshine-wav /path/audio.wav [--model medium-streaming-en] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
      swift run DictationPreviewCLI --moonshine-live [--model medium-streaming-en] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
      swift run DictationPreviewCLI --hotkey-daemon [--model medium-streaming-en] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
    """

    let mode: Mode

    static func parse(_ rawArgs: [String]) -> Arguments {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let environment = ProcessInfo.processInfo.environment

        if let transcript = value(after: "--simulate", in: rawArgs) {
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return Arguments(mode: .simulate(trimmed))
            }
        }

        if let wavPath = value(after: "--moonshine-wav", in: rawArgs) {
            let model = value(after: "--model", in: rawArgs) ?? "medium-streaming-en"
            let pythonBinary = RuntimePathResolver.resolvePythonBinary(
                explicit: value(after: "--moonshine-python", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            )
            let scriptPath = RuntimePathResolver.resolveMoonshineScriptPath(
                explicit: value(after: "--moonshine-script", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            )
            return Arguments(mode: .moonshineWAV(path: wavPath, model: model, pythonBinary: pythonBinary, scriptPath: scriptPath))
        }

        if rawArgs.contains("--moonshine-live") {
            let model = value(after: "--model", in: rawArgs) ?? "medium-streaming-en"
            let pythonBinary = RuntimePathResolver.resolvePythonBinary(
                explicit: value(after: "--moonshine-python", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            )
            let scriptPath = RuntimePathResolver.resolveMoonshineScriptPath(
                explicit: value(after: "--moonshine-script", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            )
            return Arguments(mode: .moonshineLive(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath))
        }

        if rawArgs.contains("--hotkey-daemon") {
            let model = value(after: "--model", in: rawArgs) ?? "medium-streaming-en"
            let pythonBinary = RuntimePathResolver.resolvePythonBinary(
                explicit: value(after: "--moonshine-python", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            )
            let scriptPath = RuntimePathResolver.resolveMoonshineScriptPath(
                explicit: value(after: "--moonshine-script", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            )
            return Arguments(mode: .hotkeyDaemon(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath))
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

        let value = args[next].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private final class ConsoleFieldWriter: FocusedFieldWriting {
    private(set) var lastInsertedText: String?

    func insert(_ text: String) -> InsertResult {
        lastInsertedText = text
        return .init(success: true, method: .accessibilityDirect, error: nil)
    }
}

private final class RecordingFieldWriter: FocusedFieldWriting {
    private let base: FocusedFieldWriting
    private let onInsert: ((String, InsertResult) -> Void)?
    private(set) var lastInsertedText: String?
    private(set) var lastResult: InsertResult?

    init(base: FocusedFieldWriting, onInsert: ((String, InsertResult) -> Void)? = nil) {
        self.base = base
        self.onInsert = onInsert
    }

    func insert(_ text: String) -> InsertResult {
        lastInsertedText = text
        let result = base.insert(text)
        lastResult = result
        onInsert?(text, result)
        return result
    }
}

private final class ConsoleStatusUI: StatusPresenting {
    var onError: ((FailureCode) -> Void)?

    func update(state: SessionState) {
        emit("state=\(state)")
    }

    func showPermissionPrompt(_ snapshot: PermissionSnapshot) {
        emit("permission_prompt=\(snapshot)")
    }

    func showError(_ error: FailureCode) {
        emit("error=\(error.rawValue)")
        onError?(error)
    }

    func showPartialTranscript(_ text: String) {
        emit("partial=\(text)")
    }
}

private final class ConsoleLogger: Logging {
    private(set) var messages: [String] = []
    var onLog: ((String) -> Void)?

    func log(_ message: String) {
        messages.append(message)
        onLog?(message)
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

private func emit(_ line: String) {
    Swift.print(line)
    fflush(stdout)
}
