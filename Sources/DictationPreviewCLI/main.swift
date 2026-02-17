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
        case .hotkeyDaemon(let model, let pythonBinary, let scriptPath, let shortcutIdentifier):
            runHotkeyDaemon(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath, shortcutIdentifier: shortcutIdentifier)
        case .captureShortcut:
            runCaptureShortcut()
        case .configWizard(let configDir, let defaultShortcut, let defaultRewriteMode, let defaultOpenRouterModel):
            runConfigWizard(
                configDir: configDir,
                defaultShortcut: defaultShortcut,
                defaultRewriteMode: defaultRewriteMode,
                defaultOpenRouterModel: defaultOpenRouterModel
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

    private static func runMoonshineLivePreview(model: String, pythonBinary: String, scriptPath: String) {
        let statusUI = ConsoleStatusUI()
        let writer = RecordingFieldWriter(base: FocusedFieldWriter())
        let logger = ConsoleLogger()
        let meter = LiveCaptureMeter()
        let audioCapture = AudioCapture()
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

    private static func runHotkeyDaemon(model: String, pythonBinary: String, scriptPath: String, shortcutIdentifier: String?) {
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
        defaultOpenRouterModel: String
    ) {
        guard TerminalPrompts.isInteractiveTTY else {
            fputs("interactive config requires a TTY.\n", stderr)
            terminateProcess(2)
        }

        let config = ConfigWizardStore(
            configDir: configDir,
            defaultShortcut: defaultShortcut,
            defaultRewriteMode: defaultRewriteMode,
            defaultOpenRouterModel: defaultOpenRouterModel
        )

        do {
            try ConfigWizard(prompts: TerminalPrompts(), store: config).run()
            return
        } catch ConfigWizardError.cancelled {
            fputs("config update cancelled\n", stderr)
            terminateProcess(1)
        } catch ConfigWizardError.invalid(let message) {
            fputs("invalid input: \(message)\n", stderr)
            terminateProcess(2)
        } catch {
            fputs("config wizard failed: \(error.localizedDescription)\n", stderr)
            terminateProcess(1)
        }
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

private enum ConfigWizardError: Error {
    case cancelled
    case invalid(String)
}

private enum ShortcutSelection {
    case keep
    case set(String)
    case reset
}

private enum APIKeySelection {
    case keep
    case set(String)
    case clear
}

private struct ConfigWizardState {
    let currentShortcut: String
    let currentRewriteMode: String
    let currentModel: String
    let apiKeyStored: Bool
    let apiKeySource: String
}

private struct ConfigWizardStore {
    let configDir: String
    let defaultShortcut: String
    let defaultRewriteMode: String
    let defaultOpenRouterModel: String

    var shortcutPath: String { "\(configDir)/shortcut.txt" }
    var rewriteModePath: String { "\(configDir)/rewrite_mode.txt" }
    var modelPath: String { "\(configDir)/openrouter_model.txt" }
    var apiKeyPath: String { "\(configDir)/openrouter_api_key.txt" }

    func load() -> ConfigWizardState {
        let shortcut = readValue(path: shortcutPath) ?? defaultShortcut
        let rewriteMode = normalizeRewriteMode(readValue(path: rewriteModePath)) ?? normalizeRewriteMode(defaultRewriteMode) ?? "smart"
        let model = readValue(path: modelPath) ?? defaultOpenRouterModel
        let apiKeyStored = (readValue(path: apiKeyPath) ?? "").isEmpty == false
        let apiKeySource = apiKeyStored ? "file:\(apiKeyPath)" : "unset"
        return .init(
            currentShortcut: shortcut,
            currentRewriteMode: rewriteMode,
            currentModel: model,
            apiKeyStored: apiKeyStored,
            apiKeySource: apiKeySource
        )
    }

    func persist(
        shortcut: ShortcutSelection,
        rewriteMode: String,
        openRouterModel: String?,
        apiKey: APIKeySelection
    ) throws {
        try ensureConfigDir()
        try writeValue(path: rewriteModePath, value: rewriteMode)
        if let openRouterModel {
            try writeValue(path: modelPath, value: openRouterModel)
        }

        switch shortcut {
        case .keep:
            break
        case .set(let value):
            try writeValue(path: shortcutPath, value: value)
        case .reset:
            try removeFile(path: shortcutPath)
        }

        switch apiKey {
        case .keep:
            break
        case .set(let token):
            try writeValue(path: apiKeyPath, value: token, secret: true)
        case .clear:
            try removeFile(path: apiKeyPath)
        }
    }

    private func ensureConfigDir() throws {
        try FileManager.default.createDirectory(
            atPath: configDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func readValue(path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func writeValue(path: String, value: String, secret: Bool = false) throws {
        let payload = "\(value)\n"
        guard let data = payload.data(using: .utf8) else {
            throw ConfigWizardError.invalid("failed to encode value for \(path)")
        }
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        if secret {
            try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int(0o600))], ofItemAtPath: path)
        }
    }

    private func removeFile(path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        try FileManager.default.removeItem(atPath: path)
    }
}

private struct ConfigWizard {
    let prompts: TerminalPrompts
    let store: ConfigWizardStore

    func run() throws {
        let current = store.load()

        prompts.hero(title: "Murmur Quick Config")
        prompts.note("config dir: \(store.configDir)")
        prompts.note("env vars still override persisted config at runtime")
        prompts.blank()

        let shortcutSelection = try promptShortcut(current: current.currentShortcut)
        let rewriteMode = try promptRewriteMode(current: current.currentRewriteMode)
        let model: String?
        let apiKeySelection: APIKeySelection

        if rewriteMode == "smart" {
            model = try promptOpenRouterModel(current: current.currentModel)
            apiKeySelection = try promptAPIKeyAction(source: current.apiKeySource)
        } else {
            model = nil
            apiKeySelection = try promptLiteralModeAPIKeyAction(hasStoredKey: current.apiKeyStored)
        }

        prompts.blank()
        prompts.step(5, of: 5, title: "Review and Apply")
        switch shortcutSelection {
        case .keep:
            prompts.item("Shortcut: keep '\(current.currentShortcut)'")
        case .set(let value):
            prompts.item("Shortcut: set to '\(value)'")
        case .reset:
            prompts.item("Shortcut: reset to default (\(store.defaultShortcut))")
        }
        prompts.item("Rewrite mode: \(rewriteMode)")
        if let model {
            prompts.item("OpenRouter model: \(model)")
        }
        switch apiKeySelection {
        case .keep:
            prompts.item("OpenRouter API key: keep existing source (\(current.apiKeySource))")
        case .set:
            prompts.item("OpenRouter API key: set/replace stored value")
        case .clear:
            prompts.item("OpenRouter API key: clear stored value")
        }

        prompts.blank()
        guard try prompts.confirm("Apply these changes? [y/N]: ", defaultYes: false) else {
            throw ConfigWizardError.cancelled
        }

        try store.persist(
            shortcut: shortcutSelection,
            rewriteMode: rewriteMode,
            openRouterModel: model,
            apiKey: apiKeySelection
        )
        prompts.blank()
        prompts.success("Config saved.")
    }

    private func promptShortcut(current: String) throws -> ShortcutSelection {
        prompts.step(1, of: 5, title: "Shortcut")
        prompts.item("Current: \(current)")
        prompts.item("1) Keep current")
        prompts.item("2) Capture new shortcut")
        prompts.item("3) Type shortcut manually")
        prompts.item("4) Reset to default (\(store.defaultShortcut))")

        let choice = try prompts.choice(
            prompt: "Shortcut action [1/2/3/4] (Enter keeps current): ",
            defaultValue: "1",
            valid: ["1", "2", "3", "4"]
        )

        switch choice {
        case "1":
            return .keep
        case "2":
            do {
                let captured = try captureShortcutWithFallback()
                return .set(captured)
            } catch ConfigWizardError.cancelled {
                throw ConfigWizardError.cancelled
            } catch {
                prompts.warn("shortcut capture failed: \(error.localizedDescription)")
                guard try prompts.confirm("Type shortcut manually instead? [Y/n]: ", defaultYes: true) else {
                    throw ConfigWizardError.invalid("unable to capture shortcut")
                }
                let manual = try prompts.requiredText("Shortcut combo: ")
                return .set(manual)
            }
        case "3":
            let manual = try prompts.requiredText("Shortcut combo: ")
            return .set(manual)
        case "4":
            return .reset
        default:
            throw ConfigWizardError.invalid("unknown shortcut option")
        }
    }

    private func captureShortcutWithFallback() throws -> String {
        prompts.blank()
        prompts.note("capture mode: press desired shortcut now (Escape to cancel).")
        let output = try runCaptureShortcutSubprocess()

        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let shortcutLine = lines.first(where: { $0.hasPrefix("shortcut=") }) {
            let value = String(shortcutLine.dropFirst("shortcut=".count))
            if !value.isEmpty {
                prompts.success("Captured: \(value)")
                return value
            }
        }

        if let errorLine = lines.first(where: { $0.hasPrefix("error=") }) {
            if errorLine == "error=shortcut_capture_cancelled" {
                throw ConfigWizardError.cancelled
            }
            let detailLine = lines.first(where: { $0.hasPrefix("details=") }) ?? errorLine
            throw ConfigWizardError.invalid(detailLine.replacingOccurrences(of: "details=", with: ""))
        }

        throw ConfigWizardError.invalid("shortcut capture returned unexpected output")
    }

    private func runCaptureShortcutSubprocess() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["--capture-shortcut"]
        let captureInput = FileHandle(forReadingAtPath: "/dev/tty")
        process.standardInput = captureInput ?? FileHandle.standardInput
        process.standardError = FileHandle.standardError

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()
        try? captureInput?.close()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ConfigWizardError.invalid("failed to decode shortcut capture output")
        }
        if process.terminationStatus != 0 && output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ConfigWizardError.invalid("shortcut capture process exited with status \(process.terminationStatus)")
        }
        return output
    }

    private func promptRewriteMode(current: String) throws -> String {
        prompts.blank()
        prompts.step(2, of: 5, title: "Rewrite Mode")
        prompts.item("Current: \(current)")
        prompts.item("1) literal")
        prompts.item("2) smart (OpenRouter optional)")

        let defaultValue = current == "literal" ? "1" : "2"
        let choice = try prompts.choice(
            prompt: "Rewrite mode [1/2] (Enter keeps current): ",
            defaultValue: defaultValue,
            valid: ["1", "2"]
        )

        return choice == "1" ? "literal" : "smart"
    }

    private func promptOpenRouterModel(current: String) throws -> String {
        prompts.blank()
        prompts.step(3, of: 5, title: "OpenRouter Model")
        return try prompts.text(prompt: "Model id (Enter keeps '\(current)'): ", defaultValue: current)
    }

    private func promptAPIKeyAction(source: String) throws -> APIKeySelection {
        prompts.blank()
        prompts.step(4, of: 5, title: "OpenRouter API Key")
        prompts.item("Current source: \(source)")
        prompts.item("1) Keep current")
        prompts.item("2) Set/replace stored key")
        prompts.item("3) Clear stored key")

        let choice = try prompts.choice(
            prompt: "API key action [1/2/3] (Enter keeps current): ",
            defaultValue: "1",
            valid: ["1", "2", "3"]
        )
        switch choice {
        case "1":
            return .keep
        case "2":
            let token = try prompts.requiredSecret("OpenRouter API key: ")
            return .set(token)
        case "3":
            return .clear
        default:
            throw ConfigWizardError.invalid("unknown API key option")
        }
    }

    private func promptLiteralModeAPIKeyAction(hasStoredKey: Bool) throws -> APIKeySelection {
        guard hasStoredKey else {
            return .keep
        }
        prompts.blank()
        prompts.step(4, of: 5, title: "OpenRouter API Key")
        guard try prompts.confirm("Clear stored API key while using literal mode? [y/N]: ", defaultYes: false) else {
            return .keep
        }
        return .clear
    }
}

private struct TerminalPrompts {
    private enum Ansi {
        static let reset = "\u{001B}[0m"
        static let bold = "\u{001B}[1m"
        static let dim = "\u{001B}[2m"
        static let cyan = "\u{001B}[36m"
        static let green = "\u{001B}[32m"
        static let yellow = "\u{001B}[33m"
    }

    static var isInteractiveTTY: Bool {
        isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    }

    private var supportsANSI: Bool {
        guard Self.isInteractiveTTY else {
            return false
        }
        let term = ProcessInfo.processInfo.environment["TERM"]?.lowercased() ?? ""
        return !term.isEmpty && term != "dumb"
    }

    func hero(title: String) {
        let bar = "============================================================"
        let art = #"""
                      ___
                     <__ \
                       | o|
                       | o|  ______
                       | o|  / O /
                        \ o\/ O /
                         \____/
        """#
        Swift.print(styled("\(bar)\n\(art)\n\(title)\n\(bar)", color: Ansi.cyan, bold: true))
    }

    func step(_ number: Int, of total: Int, title: String) {
        Swift.print(styled("[Step \(number)/\(total)] \(title)", color: Ansi.cyan, bold: true))
    }

    func header(_ line: String) {
        Swift.print(styled(line, bold: true))
    }

    func item(_ line: String) {
        Swift.print("  • \(line)")
    }

    func note(_ line: String) {
        Swift.print(styled(line, color: Ansi.dim))
    }

    func warn(_ line: String) {
        Swift.print(styled("warning: \(line)", color: Ansi.yellow, bold: true))
    }

    func success(_ line: String) {
        Swift.print(styled(line, color: Ansi.green, bold: true))
    }

    func blank() {
        Swift.print("")
    }

    func choice(prompt: String, defaultValue: String, valid: Set<String>) throws -> String {
        while true {
            let input = try text(prompt: prompt, defaultValue: defaultValue).lowercased()
            if valid.contains(input) {
                return input
            }
            Swift.print("Please choose one of: \(valid.sorted().joined(separator: ", "))")
        }
    }

    func text(prompt: String, defaultValue: String) throws -> String {
        guard let raw = read(prompt: prompt) else {
            throw ConfigWizardError.cancelled
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    func requiredText(_ prompt: String) throws -> String {
        while true {
            guard let raw = read(prompt: prompt) else {
                throw ConfigWizardError.cancelled
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            Swift.print("Value cannot be empty.")
        }
    }

    func requiredSecret(_ prompt: String) throws -> String {
        while true {
            guard let raw = readSecret(prompt: prompt) else {
                throw ConfigWizardError.cancelled
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            Swift.print("Value cannot be empty.")
        }
    }

    func confirm(_ prompt: String, defaultYes: Bool) throws -> Bool {
        while true {
            let raw = try text(prompt: prompt, defaultValue: defaultYes ? "y" : "n").lowercased()
            switch raw {
            case "y", "yes":
                return true
            case "n", "no":
                return false
            default:
                Swift.print("Please answer y or n.")
            }
        }
    }

    private func styled(_ value: String, color: String? = nil, bold: Bool = false) -> String {
        guard supportsANSI else {
            return value
        }
        var prefix = ""
        if bold {
            prefix += Ansi.bold
        }
        if let color {
            prefix += color
        }
        return "\(prefix)\(value)\(Ansi.reset)"
    }

    private func read(prompt: String) -> String? {
        Swift.print(prompt, terminator: "")
        fflush(stdout)
        if let line = readLine() {
            return line
        }
        return readLineFromTTY()
    }

    private func readSecret(prompt: String) -> String? {
#if canImport(Darwin) || canImport(Glibc)
        guard let raw = getpass(prompt) else {
            return nil
        }
        return String(cString: raw)
#else
        return read(prompt: prompt)
#endif
    }

    private func readLineFromTTY() -> String? {
        guard let handle = FileHandle(forReadingAtPath: "/dev/tty") else {
            return nil
        }
        defer { try? handle.close() }

        var buffer = Data()
        var sawNewline = false
        while true {
            guard let chunk = try? handle.read(upToCount: 1),
                  !chunk.isEmpty
            else {
                break
            }

            let byte = chunk[chunk.startIndex]
            if byte == 10 {
                sawNewline = true
                break
            }
            if byte == 13 {
                continue
            }
            buffer.append(byte)
        }

        if !sawNewline && buffer.isEmpty {
            return nil
        }

        return String(data: buffer, encoding: .utf8) ?? ""
    }
}

private func normalizeRewriteMode(_ raw: String?) -> String? {
    guard let raw else {
        return nil
    }
    let mode = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch mode {
    case "literal", "smart":
        return mode
    default:
        return nil
    }
}

private struct Arguments {
    enum Mode {
        case simulate(String)
        case moonshineWAV(path: String, model: String, pythonBinary: String, scriptPath: String)
        case moonshineLive(model: String, pythonBinary: String, scriptPath: String)
        case hotkeyDaemon(model: String, pythonBinary: String, scriptPath: String, shortcutIdentifier: String?)
        case captureShortcut
        case configWizard(configDir: String, defaultShortcut: String, defaultRewriteMode: String, defaultOpenRouterModel: String)
        case invalid
    }

    static let usage = """
    Usage:
      swift run DictationPreviewCLI --simulate "hello world"
      swift run DictationPreviewCLI --moonshine-wav /path/audio.wav [--model medium-streaming-en] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
      swift run DictationPreviewCLI --moonshine-live [--model medium-streaming-en] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
      swift run DictationPreviewCLI --hotkey-daemon [--model medium-streaming-en] [--shortcut ctrl+shift+space] [--moonshine-python python3] [--moonshine-script scripts/moonshine_transcribe.py]
      swift run DictationPreviewCLI --capture-shortcut
      swift run DictationPreviewCLI --config-wizard --config-dir "/path/to/config" [--default-shortcut ctrl+shift+space] [--default-rewrite-mode smart] [--default-openrouter-model mistralai/mistral-small-3.1-24b-instruct]
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
            let shortcutIdentifier = value(after: "--shortcut", in: rawArgs)
            return Arguments(mode: .hotkeyDaemon(model: model, pythonBinary: pythonBinary, scriptPath: scriptPath, shortcutIdentifier: shortcutIdentifier))
        }

        if rawArgs.contains("--capture-shortcut") {
            return Arguments(mode: .captureShortcut)
        }

        if rawArgs.contains("--config-wizard") {
            guard let configDir = value(after: "--config-dir", in: rawArgs) else {
                return Arguments(mode: .invalid)
            }
            let defaultShortcut = value(after: "--default-shortcut", in: rawArgs) ?? "ctrl+shift+space"
            let defaultRewriteMode = value(after: "--default-rewrite-mode", in: rawArgs) ?? "smart"
            let defaultOpenRouterModel = value(after: "--default-openrouter-model", in: rawArgs) ?? "mistralai/mistral-small-3.1-24b-instruct"
            return Arguments(
                mode: .configWizard(
                    configDir: configDir,
                    defaultShortcut: defaultShortcut,
                    defaultRewriteMode: defaultRewriteMode,
                    defaultOpenRouterModel: defaultOpenRouterModel
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

private func terminateProcess(_ code: Int32) -> Never {
#if canImport(Darwin)
    Darwin.exit(code)
#elseif canImport(Glibc)
    Glibc.exit(code)
#else
    fatalError("unsupported platform exit for code \(code)")
#endif
}

private func emit(_ line: String) {
    Swift.print(line)
    fflush(stdout)
}
