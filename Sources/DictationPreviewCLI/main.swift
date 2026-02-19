import Foundation
import DictationAppCore
#if canImport(Carbon)
import Carbon
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct DictationPreviewCLI {
    static func main() {
        let args = Arguments.parse(CommandLine.arguments)
        switch args.mode {
        case .simulate(let transcript):
            runSimulatedPreview(transcript: transcript)
        case .moonshineWAV(let wavPath, let model, let pythonBinary, let scriptPath):
            runMoonshinePreview(wavPath: wavPath, model: model, pythonBinary: pythonBinary, scriptPath: scriptPath)
        case .moonshineLive(let model, let pythonBinary, let scriptPath, let microphone):
            runMoonshineLivePreview(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath, microphone: microphone)
        case .hotkeyDaemon(let model, let pythonBinary, let scriptPath, let shortcutIdentifier, let microphone):
            runHotkeyDaemon(
                model: model,
                pythonBinary: pythonBinary,
                scriptPath: scriptPath,
                shortcutIdentifier: shortcutIdentifier,
                microphone: microphone
            )
        case .listMicrophones:
            runListMicrophones()
        case .captureShortcut:
            runCaptureShortcut()
        case .configWizard(
            let configDir,
            let defaultShortcut,
            let defaultRewriteMode,
            let defaultOpenRouterModel,
            let defaultPauseMediaWhileRecording
        ):
            runConfigWizard(
                configDir: configDir,
                defaultShortcut: defaultShortcut,
                defaultRewriteMode: defaultRewriteMode,
                defaultOpenRouterModel: defaultOpenRouterModel,
                defaultPauseMediaWhileRecording: defaultPauseMediaWhileRecording
            )
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

    private static func runListMicrophones() {
        do {
            let devices = try AudioCapture.availableInputDevices()
            if devices.isEmpty {
                emit("microphones=none")
                return
            }

            for device in devices {
                emit(
                    "microphone id=\"\(escapedLogValue(device.id))\" name=\"\(escapedLogValue(device.name))\" default=\(device.isDefault)"
                )
            }
        } catch {
            emit("error=list_microphones_failed")
            emit("details=\(error)")
        }
    }

    private static func runMoonshineLivePreview(
        model: String,
        pythonBinary: String,
        scriptPath: String,
        microphone: String?
    ) {
        let statusUI = ConsoleStatusUI()
        let writer = RecordingFieldWriter(base: FocusedFieldWriter())
        let logger = ConsoleLogger()
        let meter = LiveCaptureMeter()
        let audioCapture = AudioCapture(preferredInputDevice: microphone)
        let transcriptHistory = FileTranscriptHistoryStore()
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
            transcriptHistory: transcriptHistory,
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
        if let microphone {
            emit("microphone_selected=\"\(escapedLogValue(microphone))\"")
        } else {
            emit("microphone_selected=\"system_default\"")
        }
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

    private static func runHotkeyDaemon(
        model: String,
        pythonBinary: String,
        scriptPath: String,
        shortcutIdentifier: String?,
        microphone: String?
    ) {
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

        let audioCapture = AudioCapture(preferredInputDevice: microphone)
        let transcriptHistory = FileTranscriptHistoryStore()
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
            transcriptHistory: transcriptHistory,
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

        let shortcutResolution = resolveHotkeyShortcuts(shortcutIdentifier: shortcutIdentifier)
        if let warning = shortcutResolution.warning {
            emit("warning=\(warning)")
        }
        let hotkeyController = HotkeyController(shortcuts: shortcutResolution.shortcuts)
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

        if let microphone {
            emit("microphone_selected=\"\(escapedLogValue(microphone))\"")
        } else {
            emit("microphone_selected=\"system_default\"")
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
        let shortcutHint = hotkeyController.shortcutSummary.replacingOccurrences(of: "|", with: "_or_")
        emit("hint=focus_any_textbox_hold_\(shortcutHint)_speak_release_to_insert")
        #else
        emit("hotkey_daemon=running shortcuts=ctrl+shift+space|ctrl+shift+d")
        emit("hotkey_backend=none")
        emit("hint=focus_any_textbox_hold_ctrl_shift_space_or_ctrl_shift_d_speak_release_to_insert")
        #endif
#if canImport(Carbon)
        while true {
            _ = RunCurrentEventLoop(0.25)
        }
#else
        RunLoop.main.run()
#endif
    }

    private static func runCaptureShortcut() {
#if canImport(CoreGraphics) && canImport(Carbon)
        fputs("Press the shortcut you want to use (must include ctrl/shift/option/cmd).\n", stderr)
        fputs("Press Escape to cancel.\n", stderr)

        switch ShortcutCapture.capture() {
        case .captured(let shortcut):
            emit("shortcut=\(shortcut.identifier)")
        case .cancelled:
            emit("error=shortcut_capture_cancelled")
        case .failed(let reason):
            emit("error=shortcut_capture_failed")
            emit("details=\(reason)")
        }
#else
        emit("error=shortcut_capture_unsupported")
#endif
    }

    private static func runConfigWizard(
        configDir: String,
        defaultShortcut: String,
        defaultRewriteMode: String,
        defaultOpenRouterModel: String,
        defaultPauseMediaWhileRecording: Bool
    ) {
        TermKitConfigWizard.run(
            configDir: configDir,
            defaultShortcut: defaultShortcut,
            defaultRewriteMode: defaultRewriteMode,
            defaultOpenRouterModel: defaultOpenRouterModel,
            defaultPauseMediaWhileRecording: defaultPauseMediaWhileRecording
        )
    }

    private static func resolveHotkeyShortcuts(shortcutIdentifier: String?) -> (shortcuts: [HotkeyShortcut], warning: String?) {
        let defaults: [HotkeyShortcut] = [.defaultPushToTalk, .defaultBackupPushToTalk]
        guard let shortcutIdentifier else {
            return (defaults, nil)
        }

        guard let parsed = HotkeyShortcut.parse(identifier: shortcutIdentifier) else {
            return (defaults, "invalid shortcut identifier '\(shortcutIdentifier)'; using defaults")
        }

        var resolved = [parsed]
        if parsed != .defaultBackupPushToTalk {
            resolved.append(.defaultBackupPushToTalk)
        }
        return (resolved, nil)
    }
}

private struct Arguments {
    enum Mode {
        case simulate(String)
        case moonshineWAV(path: String, model: String, pythonBinary: String, scriptPath: String)
        case moonshineLive(model: String, pythonBinary: String, scriptPath: String, microphone: String?)
        case hotkeyDaemon(model: String, pythonBinary: String, scriptPath: String, shortcutIdentifier: String?, microphone: String?)
        case listMicrophones
        case captureShortcut
        case configWizard(
            configDir: String,
            defaultShortcut: String,
            defaultRewriteMode: String,
            defaultOpenRouterModel: String,
            defaultPauseMediaWhileRecording: Bool
        )
        case invalid
    }

    static let usage = """
    Usage:
      swift run DictationPreviewCLI --simulate "hello world"
      swift run DictationPreviewCLI --moonshine-wav /path/audio.wav [--model medium-streaming-en] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
      swift run DictationPreviewCLI --moonshine-live [--model medium-streaming-en] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py] [--microphone "<name-or-uid>"]
      swift run DictationPreviewCLI --hotkey-daemon [--model medium-streaming-en] [--shortcut ctrl+shift+space] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py] [--microphone "<name-or-uid>"]
      swift run DictationPreviewCLI --list-microphones
      swift run DictationPreviewCLI --capture-shortcut
      swift run DictationPreviewCLI --config-wizard --config-dir "/path/to/config" [--default-shortcut ctrl+shift+space] [--default-rewrite-mode literal] [--default-openrouter-model mistralai/mistral-small-3.1-24b-instruct] [--default-pause-media-while-recording false]
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
            return Arguments(
                mode: .moonshineLive(
                    model: model,
                    pythonBinary: pythonBinary,
                    scriptPath: scriptPath,
                    microphone: value(after: "--microphone", in: rawArgs)
                )
            )
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
            let shortcutIdentifier = value(after: "--shortcut", in: rawArgs)
            return Arguments(
                mode: .hotkeyDaemon(
                    model: model,
                    pythonBinary: pythonBinary,
                    scriptPath: scriptPath,
                    shortcutIdentifier: shortcutIdentifier,
                    microphone: value(after: "--microphone", in: rawArgs)
                )
            )
        }

        if rawArgs.contains("--list-microphones") {
            return Arguments(mode: .listMicrophones)
        }

        if rawArgs.contains("--capture-shortcut") {
            return Arguments(mode: .captureShortcut)
        }

        if rawArgs.contains("--config-wizard") {
            guard let configDir = value(after: "--config-dir", in: rawArgs) else {
                return Arguments(mode: .invalid)
            }
            let defaultShortcut = value(after: "--default-shortcut", in: rawArgs) ?? "ctrl+shift+space"
            let defaultRewriteMode = value(after: "--default-rewrite-mode", in: rawArgs) ?? "literal"
            let defaultOpenRouterModel = value(after: "--default-openrouter-model", in: rawArgs) ?? "mistralai/mistral-small-3.1-24b-instruct"
            let defaultPauseMediaRaw = value(after: "--default-pause-media-while-recording", in: rawArgs) ?? "false"
            let defaultPauseMedia = parseBool(defaultPauseMediaRaw) ?? false
            return Arguments(
                mode: .configWizard(
                    configDir: configDir,
                    defaultShortcut: defaultShortcut,
                    defaultRewriteMode: defaultRewriteMode,
                    defaultOpenRouterModel: defaultOpenRouterModel,
                    defaultPauseMediaWhileRecording: defaultPauseMedia
                )
            )
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

    private static func parseBool(_ rawValue: String) -> Bool? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}

#if canImport(CoreGraphics) && canImport(Carbon)
private enum ShortcutCaptureResult {
    case captured(HotkeyShortcut)
    case cancelled
    case failed(String)
}

nonisolated(unsafe) private var shortcutCaptureResult: ShortcutCaptureResult?

private func shortcutCaptureCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags.intersection([.maskControl, .maskShift, .maskAlternate, .maskCommand])
    let modifiers = ShortcutCapture.carbonModifiers(from: flags)

    if keyCode == UInt32(kVK_Escape), modifiers == 0 {
        shortcutCaptureResult = .cancelled
        CFRunLoopStop(CFRunLoopGetCurrent())
        return Unmanaged.passUnretained(event)
    }

    guard modifiers != 0 else {
        return Unmanaged.passUnretained(event)
    }

    shortcutCaptureResult = .captured(.init(keyCode: keyCode, modifiers: modifiers))
    CFRunLoopStop(CFRunLoopGetCurrent())
    return Unmanaged.passUnretained(event)
}

private enum ShortcutCapture {
    private static let monitoredEventMask: CGEventMask = {
        let keyDownMask = (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue))
        return keyDownMask
    }()

    static func capture() -> ShortcutCaptureResult {
        shortcutCaptureResult = nil

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: monitoredEventMask,
            callback: shortcutCaptureCallback,
            userInfo: nil
        ) else {
            return .failed("event tap unavailable (check Input Monitoring permission for terminal)")
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return .failed("failed to create run loop source")
        }

        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(runLoop, source, .commonModes)

        return shortcutCaptureResult ?? .failed("no shortcut captured")
    }

    static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.maskControl) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.maskShift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.maskAlternate) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.maskCommand) {
            modifiers |= UInt32(cmdKey)
        }
        return modifiers
    }
}
#endif

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

private func escapedLogValue(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
}

private func emit(_ line: String) {
    Swift.print(RuntimeLogFormatter.format(line))
    fflush(stdout)
}

DictationPreviewCLI.main()
