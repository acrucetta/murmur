import Foundation

#if canImport(AppKit)
import AppKit
import DictationAppCore

private func escapeLogValue(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
}

@main
struct MurmurMenuBarApp {
    static func main() {
        let arguments = Arguments.parse(CommandLine.arguments)
        if let warning = arguments.shortcutWarning {
            emit("warning=\(warning)")
        }
        if let warning = arguments.overlayWarning {
            emit("warning=\(warning)")
        }
        if let warning = arguments.rewriteWarning {
            emit("warning=\(warning)")
        }
        if let warning = arguments.openRouterTimeoutWarning {
            emit("warning=\(warning)")
        }
        if let warning = arguments.pauseMediaWarning {
            emit("warning=\(warning)")
        }
        if let warning = arguments.toggleModeWarning {
            emit("warning=\(warning)")
        }
        if let warning = arguments.microphoneWarning {
            emit("warning=\(warning)")
        }
        let menuBarController = MenuBarController()
        let runtime = MenuBarRuntime(
            menuBarController: menuBarController,
            model: arguments.model,
            pythonBinary: arguments.pythonBinary,
            scriptPath: arguments.scriptPath,
            configDirectory: arguments.configDirectory,
            hotkeyShortcuts: arguments.hotkeyShortcuts,
            overlayPreviewState: arguments.overlayPreviewState,
            rewriteMode: arguments.rewriteMode,
            openRouterModel: arguments.openRouterModel,
            openRouterAPIKey: arguments.openRouterAPIKey,
            openRouterRequestTimeoutSeconds: arguments.openRouterRequestTimeoutSeconds,
            pauseMediaWhileRecording: arguments.pauseMediaWhileRecording,
            toggleMode: arguments.toggleMode,
            preferredMicrophone: arguments.preferredMicrophone
        )

        let delegate = AppDelegate(
            menuBarController: menuBarController,
            onLaunch: {
                runtime.start()
            },
            onTerminate: {
                runtime.stop()
            }
        )

        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}

private struct Arguments {
    let model: String
    let pythonBinary: String
    let scriptPath: String
    let configDirectory: String
    let hotkeyShortcuts: [HotkeyShortcut]
    let shortcutWarning: String?
    let overlayPreviewState: OverlayPreviewState?
    let overlayWarning: String?
    let rewriteMode: TranscriptRewriteMode
    let openRouterModel: String
    let openRouterAPIKey: String?
    let openRouterRequestTimeoutSeconds: TimeInterval
    let rewriteWarning: String?
    let openRouterTimeoutWarning: String?
    let pauseMediaWhileRecording: Bool
    let pauseMediaWarning: String?
    let toggleMode: Bool
    let toggleModeWarning: String?
    let preferredMicrophone: String?
    let microphoneWarning: String?

    static func parse(_ rawArgs: [String]) -> Arguments {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let environment = ProcessInfo.processInfo.environment
        let shortcutIdentifier = value(after: "--shortcut", in: rawArgs)
        let shortcutResolution = resolveHotkeyShortcuts(shortcutIdentifier: shortcutIdentifier)
        let overlayPreviewResolution = resolveOverlayPreviewState(
            previewIdentifier: value(after: "--overlay-preview", in: rawArgs)
        )
        let rewriteResolution = resolveRewriteMode(
            explicit: value(after: "--rewrite-mode", in: rawArgs),
            environment: environment
        )
        let openRouterTimeoutResolution = resolveOpenRouterRequestTimeoutSeconds(
            explicitMilliseconds: value(after: "--openrouter-timeout-ms", in: rawArgs),
            environment: environment
        )
        let pauseMediaResolution = resolvePauseMediaWhileRecording(
            explicit: value(after: "--pause-media-while-recording", in: rawArgs),
            environment: environment
        )
        let toggleModeResolution = resolveToggleMode(
            explicit: value(after: "--toggle-mode", in: rawArgs),
            environment: environment
        )
        let microphoneResolution = resolvePreferredMicrophone(
            explicit: value(after: "--microphone", in: rawArgs),
            environment: environment
        )

        return Arguments(
            model: value(after: "--model", in: rawArgs) ?? "medium-streaming-en",
            pythonBinary: RuntimePathResolver.resolvePythonBinary(
                explicit: value(after: "--moonshine-python", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            ),
            scriptPath: RuntimePathResolver.resolveMoonshineScriptPath(
                explicit: value(after: "--moonshine-script", in: rawArgs),
                currentDirectory: currentDirectory,
                environment: environment
            ),
            configDirectory: resolveConfigDirectory(environment: environment),
            hotkeyShortcuts: shortcutResolution.shortcuts,
            shortcutWarning: shortcutResolution.warning,
            overlayPreviewState: overlayPreviewResolution.state,
            overlayWarning: overlayPreviewResolution.warning,
            rewriteMode: rewriteResolution.mode,
            openRouterModel: resolveOpenRouterModel(explicit: value(after: "--openrouter-model", in: rawArgs), environment: environment),
            openRouterAPIKey: resolveOpenRouterAPIKey(explicit: value(after: "--openrouter-api-key", in: rawArgs), environment: environment),
            openRouterRequestTimeoutSeconds: openRouterTimeoutResolution.seconds,
            rewriteWarning: rewriteResolution.warning,
            openRouterTimeoutWarning: openRouterTimeoutResolution.warning,
            pauseMediaWhileRecording: pauseMediaResolution.enabled,
            pauseMediaWarning: pauseMediaResolution.warning,
            toggleMode: toggleModeResolution.enabled,
            toggleModeWarning: toggleModeResolution.warning,
            preferredMicrophone: microphoneResolution.microphone,
            microphoneWarning: microphoneResolution.warning
        )
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag) else {
            return nil
        }
        let next = args.index(after: index)
        guard next < args.endIndex else {
            return nil
        }
        return args[next].trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func resolveOverlayPreviewState(
        previewIdentifier: String?
    ) -> (state: OverlayPreviewState?, warning: String?) {
        guard let previewIdentifier else {
            return (nil, nil)
        }

        guard let previewState = OverlayPreviewState.parse(previewIdentifier) else {
            return (
                nil,
                "invalid overlay preview '\(previewIdentifier)'; expected one of: idle|idle-hover|listening|finalizing|error"
            )
        }

        return (previewState, nil)
    }

    private static func resolveRewriteMode(
        explicit: String?,
        environment: [String: String]
    ) -> (mode: TranscriptRewriteMode, warning: String?) {
        if let explicit {
            guard let parsed = TranscriptRewriteMode.parse(explicit) else {
                return (.literal, "invalid rewrite mode '\(explicit)'; expected literal|smart")
            }
            return (parsed, nil)
        }

        if let envValue = environment["MURMUR_REWRITE_MODE"], !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsed = TranscriptRewriteMode.parse(envValue) else {
                return (.literal, "invalid MURMUR_REWRITE_MODE '\(envValue)'; expected literal|smart")
            }
            return (parsed, nil)
        }

        return (.literal, nil)
    }

    private static func resolveOpenRouterModel(explicit: String?, environment: [String: String]) -> String {
        if let explicit, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicit
        }
        if let envValue = environment["MURMUR_OPENROUTER_MODEL"], !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envValue
        }
        return "mistralai/mistral-small-3.1-24b-instruct"
    }

    private static func resolveOpenRouterAPIKey(explicit: String?, environment: [String: String]) -> String? {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let envValue = environment["MURMUR_OPENROUTER_API_KEY"] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let envValue = environment["OPENROUTER_API_KEY"] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    private static func resolveOpenRouterRequestTimeoutSeconds(
        explicitMilliseconds: String?,
        environment: [String: String]
    ) -> (seconds: TimeInterval, warning: String?) {
        let defaultMilliseconds: Double = 700

        if let explicitMilliseconds {
            guard let value = parsePositiveMilliseconds(explicitMilliseconds) else {
                return (
                    defaultMilliseconds / 1000,
                    "invalid openrouter-timeout-ms '\(explicitMilliseconds)'; expected positive milliseconds"
                )
            }
            return (value / 1000, nil)
        }

        if let envValue = environment["MURMUR_OPENROUTER_TIMEOUT_MS"],
           !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            guard let value = parsePositiveMilliseconds(envValue) else {
                return (
                    defaultMilliseconds / 1000,
                    "invalid MURMUR_OPENROUTER_TIMEOUT_MS '\(envValue)'; expected positive milliseconds"
                )
            }
            return (value / 1000, nil)
        }

        return (defaultMilliseconds / 1000, nil)
    }

    private static func parsePositiveMilliseconds(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Double(trimmed), parsed > 0 else {
            return nil
        }
        return parsed
    }

    private static func resolvePauseMediaWhileRecording(
        explicit: String?,
        environment: [String: String]
    ) -> (enabled: Bool, warning: String?) {
        if let explicit {
            guard let parsed = parseBool(explicit) else {
                return (
                    false,
                    "invalid pause-media value '\(explicit)'; expected true|false"
                )
            }
            return (parsed, nil)
        }

        if let envValue = environment["MURMUR_PAUSE_MEDIA_WHILE_RECORDING"],
           !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            guard let parsed = parseBool(envValue) else {
                return (
                    false,
                    "invalid MURMUR_PAUSE_MEDIA_WHILE_RECORDING '\(envValue)'; expected true|false"
                )
            }
            return (parsed, nil)
        }

        return (false, nil)
    }

    private static func resolveToggleMode(
        explicit: String?,
        environment: [String: String]
    ) -> (enabled: Bool, warning: String?) {
        if let explicit {
            guard let parsed = parseBool(explicit) else {
                return (
                    false,
                    "invalid toggle-mode value '\(explicit)'; expected true|false"
                )
            }
            return (parsed, nil)
        }

        if let envValue = environment["MURMUR_TOGGLE_MODE"],
           !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            guard let parsed = parseBool(envValue) else {
                return (
                    false,
                    "invalid MURMUR_TOGGLE_MODE '\(envValue)'; expected true|false"
                )
            }
            return (parsed, nil)
        }

        return (false, nil)
    }

    private static func resolvePreferredMicrophone(
        explicit: String?,
        environment: [String: String]
    ) -> (microphone: String?, warning: String?) {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return (trimmed, nil)
            }
            return (nil, nil)
        }

        if let envValue = environment["MURMUR_MICROPHONE"] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return (trimmed, nil)
            }
        }

        return (nil, nil)
    }

    private static func parseBool(_ rawValue: String) -> Bool? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }

    private static func resolveConfigDirectory(environment: [String: String]) -> String {
        if let explicit = environment["MURMUR_CONFIG_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty
        {
            return explicit
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Murmur")
            .path
    }

}

private struct MenuBarConfigSnapshot {
    var shortcutIdentifier: String
    var rewriteMode: TranscriptRewriteMode
    var openRouterModel: String
    var pauseMediaWhileRecording: Bool
    var toggleMode: Bool
    var preferredMicrophone: String?
    var availableMicrophones: [AudioInputDevice]

    var menuSnapshot: MenuBarSettingsSnapshot {
        .init(
            shortcutIdentifier: shortcutIdentifier,
            rewriteMode: rewriteMode,
            openRouterModel: openRouterModel,
            pauseMediaWhileRecording: pauseMediaWhileRecording,
            toggleMode: toggleMode,
            preferredMicrophone: preferredMicrophone,
            availableMicrophones: availableMicrophones
        )
    }
}

private struct MurmurConfigStore {
    private let configDirectory: String
    private let fileManager: FileManager

    private var rewriteModePath: String { "\(configDirectory)/rewrite_mode.txt" }
    private var openRouterModelPath: String { "\(configDirectory)/openrouter_model.txt" }
    private var pauseMediaPath: String { "\(configDirectory)/pause_media_while_recording.txt" }
    private var toggleModePath: String { "\(configDirectory)/toggle_mode.txt" }
    private var microphonePath: String { "\(configDirectory)/microphone.txt" }

    init(configDirectory: String, fileManager: FileManager = .default) {
        self.configDirectory = configDirectory
        self.fileManager = fileManager
    }

    func persistRewriteMode(_ mode: TranscriptRewriteMode) throws {
        try writeValue(mode.rawValue, to: rewriteModePath)
    }

    func persistOpenRouterModel(_ model: String) throws {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        try writeValue(trimmed, to: openRouterModelPath)
    }

    func persistPauseMediaWhileRecording(_ enabled: Bool) throws {
        try writeValue(enabled ? "true" : "false", to: pauseMediaPath)
    }

    func persistToggleMode(_ enabled: Bool) throws {
        try writeValue(enabled ? "true" : "false", to: toggleModePath)
    }

    func persistPreferredMicrophone(_ microphone: String?) throws {
        guard let microphone else {
            try removeValue(at: microphonePath)
            return
        }

        let trimmed = microphone.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try removeValue(at: microphonePath)
        } else {
            try writeValue(trimmed, to: microphonePath)
        }
    }

    private func ensureConfigDirectory() throws {
        try fileManager.createDirectory(
            atPath: configDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func writeValue(_ value: String, to path: String) throws {
        try ensureConfigDirectory()
        let payload = "\(value)\n"
        guard let data = payload.data(using: .utf8) else {
            return
        }
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func removeValue(at path: String) throws {
        guard fileManager.fileExists(atPath: path) else {
            return
        }
        try fileManager.removeItem(atPath: path)
    }
}

@MainActor
private final class MenuBarRuntime {
    private let menuBarController: MenuBarController
    private let statusUI: MenuBarStatusUI
    private let logger: MenuBarLogger
    private let audioCapture: AudioCapture
    private let asrEngine: MoonshineProcessASREngine
    private let orchestrator: SessionOrchestrator
    private let hotkeyController: HotkeyController
    private let bridge: HotkeySessionBridge
    private let overlayController: RecordingOverlayController
    private let overlayPreviewState: OverlayPreviewState?
    private let primaryShortcut: HotkeyShortcut
    private let configStore: MurmurConfigStore
    private let recordingMediaController: SwitchableRecordingMediaController
    private var menuConfigSnapshot: MenuBarConfigSnapshot

    init(
        menuBarController: MenuBarController,
        model: String,
        pythonBinary: String,
        scriptPath: String,
        configDirectory: String,
        hotkeyShortcuts: [HotkeyShortcut],
        overlayPreviewState: OverlayPreviewState?,
        rewriteMode: TranscriptRewriteMode,
        openRouterModel: String,
        openRouterAPIKey: String?,
        openRouterRequestTimeoutSeconds: TimeInterval,
        pauseMediaWhileRecording: Bool,
        toggleMode: Bool,
        preferredMicrophone: String?
    ) {
        self.menuBarController = menuBarController
        self.overlayPreviewState = overlayPreviewState

        let primaryShortcut = hotkeyShortcuts.first ?? .defaultPushToTalk
        let overlayController = RecordingOverlayController(
            promptText: HotkeyShortcutPresentation.overlayPrompt(for: primaryShortcut, toggleMode: toggleMode),
            previewState: overlayPreviewState
        )
        let statusUI = MenuBarStatusUI(menuBarController: menuBarController)
        let logger = MenuBarLogger()
        let configStore = MurmurConfigStore(configDirectory: configDirectory)
        let audioCapture = AudioCapture(preferredInputDevice: preferredMicrophone)
        let transcriptHistory = FileTranscriptHistoryStore()
        let asrEngine = MoonshineProcessASREngine(
            command: [pythonBinary, scriptPath],
            model: model
        )
        let contextProvider = AppRewriteContextProvider(mode: rewriteMode)
        let transcriptRewriter: TranscriptRewriting
        if rewriteMode == .smart,
           let openRouterAPIKey,
           !openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            transcriptRewriter = OpenRouterTranscriptRewriter(
                config: .init(
                    apiKey: openRouterAPIKey,
                    model: openRouterModel,
                    requestTimeoutSeconds: openRouterRequestTimeoutSeconds
                ),
                logger: logger
            )
            let timeoutMs = max(1, Int((openRouterRequestTimeoutSeconds * 1000).rounded()))
            logger.log("smart_rewrite_enabled provider=openrouter model=\(openRouterModel) timeout_ms=\(timeoutMs)")
        } else {
            transcriptRewriter = NoopTranscriptRewriter()
            if rewriteMode == .smart {
                logger.log("smart_rewrite_disabled reason=missing_api_key")
            }
        }
        let postProcessorMode: TextPostProcessorV2.Mode = rewriteMode == .literal ? .literal : .smart
        let feedback = AppFeedbackPresenter(
            onRecordingStarted: {
                overlayController.update(state: .listening)
            },
            onRecordingStopped: {
                overlayController.update(state: .finalizing)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    overlayController.update(state: .idle)
                }
            }
        )
        let initialRecordingMediaController = Self.makeRecordingMediaController(
            enabled: pauseMediaWhileRecording,
            logger: logger
        )
        let recordingMediaController = SwitchableRecordingMediaController(
            initialController: initialRecordingMediaController
        )
        logger.log("toggle_mode enabled=\(toggleMode)")
        if let preferredMicrophone {
            logger.log("microphone_selected value=\"\(escapeLogValue(preferredMicrophone))\"")
        } else {
            logger.log("microphone_selected value=\"system_default\"")
        }

        let availableMicrophones: [AudioInputDevice]
        do {
            availableMicrophones = try AudioCapture.availableInputDevices()
        } catch {
            availableMicrophones = []
            logger.log("microphone_enumeration_failed error=\"\(escapeLogValue(error.localizedDescription))\"")
        }

        let initialMenuConfigSnapshot = MenuBarConfigSnapshot(
            shortcutIdentifier: primaryShortcut.identifier,
            rewriteMode: rewriteMode,
            openRouterModel: openRouterModel,
            pauseMediaWhileRecording: pauseMediaWhileRecording,
            toggleMode: toggleMode,
            preferredMicrophone: preferredMicrophone,
            availableMicrophones: availableMicrophones
        )

        let orchestrator = SessionOrchestrator(
            permissionManager: PermissionManager(initialSnapshot: .allGranted),
            audioCapture: audioCapture,
            asrEngine: asrEngine,
            postProcessor: TextPostProcessorV2(mode: postProcessorMode),
            transcriptRewriter: transcriptRewriter,
            rewriteContextProvider: contextProvider,
            fieldWriter: FocusedFieldWriter(),
            statusUI: statusUI,
            feedback: feedback,
            recordingMediaController: recordingMediaController,
            transcriptHistory: transcriptHistory,
            logger: logger
        )
        let hotkeyController = HotkeyController(shortcuts: hotkeyShortcuts)
        let bridge = HotkeySessionBridge(
            hotkeyController: hotkeyController,
            sessionEventHandler: orchestrator,
            toggleMode: toggleMode
        )

        overlayController.onStopRequested = { [weak orchestrator, weak bridge] in
            bridge?.resetToggleState()
            orchestrator?.handle(.shortcutReleased(.init(timestamp: Date())))
        }
        overlayController.onDismissRequested = {
            logger.log("overlay_dismissed")
        }

        self.statusUI = statusUI
        self.logger = logger
        self.audioCapture = audioCapture
        self.asrEngine = asrEngine
        self.orchestrator = orchestrator
        self.hotkeyController = hotkeyController
        self.bridge = bridge
        self.overlayController = overlayController
        self.primaryShortcut = primaryShortcut
        self.configStore = configStore
        self.recordingMediaController = recordingMediaController
        menuConfigSnapshot = initialMenuConfigSnapshot

        statusUI.onError = { error in
            guard error == .engineError else {
                return
            }
            if let engineError = asrEngine.lastError {
                Task { @MainActor in
                    menuBarController.setLastErrorMessage("engine: \(engineError)")
                }
            }
        }

        menuBarController.onSettingsAction = { [weak self] action in
            Task { @MainActor in
                self?.handleMenuSettingsAction(action)
            }
        }
        menuBarController.setSettings(initialMenuConfigSnapshot.menuSnapshot)
    }

    func start() {
        let orchestrator = self.orchestrator
        let menuBarController = self.menuBarController
        let hotkeyController = self.hotkeyController
        let logger = self.logger
        let overlayController = self.overlayController

        audioCapture.onFrame = { frame in
            orchestrator.handle(.audioFrame(frame))
            Task { @MainActor in
                overlayController.updateAudioLevel(from: frame)
            }
        }
        audioCapture.onError = { [weak self] error in
            Task { @MainActor in
                self?.handleAudioCaptureError(error)
            }
        }

        Task { @MainActor in
            overlayController.start()
        }

        if let overlayPreviewState {
            Task { @MainActor in
                overlayController.showPreview(state: overlayPreviewState)
            }
            logger.log("menu_bar_overlay_preview state=\(overlayPreviewState.rawValue)")
            return
        }

        do {
            try bridge.start()
            let backendSummary = hotkeyController.backendSummary
            Task { @MainActor in
                menuBarController.setBackend(backendSummary)
            }
            logger.log("menu_bar_started shortcuts=\(hotkeyController.shortcutSummary) backend=\(backendSummary)")
        } catch {
            Task { @MainActor in
                menuBarController.setLastErrorMessage("hotkey: \(error.localizedDescription)")
                menuBarController.setState(.error(.engineError))
            }
            logger.log("menu_bar_start_failed error=\(error)")
        }
    }

    func stop() {
        bridge.stop()
        Task { @MainActor in
            overlayController.stop()
        }
        logger.log("menu_bar_stopped")
    }

    private func handleMenuSettingsAction(_ action: MenuBarSettingsAction) {
        do {
            switch action {
            case .setRewriteMode(let mode):
                try configStore.persistRewriteMode(mode)
                menuConfigSnapshot.rewriteMode = mode
                logger.log("menu_settings_updated key=rewrite_mode value=\(mode.rawValue)")
            case .setOpenRouterModel(let model):
                try configStore.persistOpenRouterModel(model)
                menuConfigSnapshot.openRouterModel = model
                logger.log("menu_settings_updated key=openrouter_model value=\"\(escapeLogValue(model))\"")
            case .setPauseMediaWhileRecording(let enabled):
                try configStore.persistPauseMediaWhileRecording(enabled)
                menuConfigSnapshot.pauseMediaWhileRecording = enabled
                logger.log("menu_settings_updated key=pause_media_while_recording value=\(enabled)")
                if !enabled {
                    recordingMediaController.resumeMediaAfterRecording()
                }
                recordingMediaController.setController(
                    Self.makeRecordingMediaController(enabled: enabled, logger: logger)
                )
            case .setToggleMode(let enabled):
                try configStore.persistToggleMode(enabled)
                menuConfigSnapshot.toggleMode = enabled
                bridge.toggleMode = enabled
                bridge.resetToggleState()
                overlayController.updatePromptText(
                    HotkeyShortcutPresentation.overlayPrompt(for: primaryShortcut, toggleMode: enabled)
                )
                logger.log("menu_settings_updated key=toggle_mode value=\(enabled)")
            case .setPreferredMicrophone(let microphone):
                try configStore.persistPreferredMicrophone(microphone)
                menuConfigSnapshot.preferredMicrophone = microphone
                if let microphone, !microphone.isEmpty {
                    logger.log("menu_settings_updated key=microphone value=\"\(escapeLogValue(microphone))\"")
                } else {
                    logger.log("menu_settings_updated key=microphone value=\"system_default\"")
                }
            }

            menuBarController.setSettings(menuConfigSnapshot.menuSnapshot)
        } catch {
            logger.log("menu_settings_update_failed error=\"\(escapeLogValue(error.localizedDescription))\"")
        }
    }

    private func handleAudioCaptureError(_ error: Error) {
        logger.log("audio_capture_error error=\"\(escapeLogValue(error.localizedDescription))\"")
        menuBarController.setLastErrorMessage("audio: \(error.localizedDescription)")

        guard case AudioCaptureError.inputDeviceNotFound(let missingIdentifier) = error else {
            return
        }

        guard let configuredMicrophone = menuConfigSnapshot.preferredMicrophone,
              configuredMicrophone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return
        }

        let normalizedConfigured = configuredMicrophone.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMissing = missingIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedConfigured == normalizedMissing else {
            return
        }

        do {
            try configStore.persistPreferredMicrophone(nil)
            menuConfigSnapshot.preferredMicrophone = nil
            menuBarController.setSettings(menuConfigSnapshot.menuSnapshot)
            logger.log(
                "menu_settings_auto_cleared key=microphone reason=input_device_not_found value=\"\(escapeLogValue(normalizedMissing))\""
            )
        } catch {
            logger.log("menu_settings_auto_clear_failed key=microphone error=\"\(escapeLogValue(error.localizedDescription))\"")
        }
    }

    private static func makeRecordingMediaController(
        enabled: Bool,
        logger: Logging
    ) -> RecordingMediaControlling {
        if enabled {
            logger.log("pause_media_while_recording enabled=true")
            return AppleScriptRecordingMediaController(logger: logger)
        }
        logger.log("pause_media_while_recording enabled=false")
        return NoopRecordingMediaController()
    }
}

private final class MenuBarStatusUI: StatusPresenting {
    private weak var menuBarController: MenuBarController?
    var onError: ((FailureCode) -> Void)?

    init(menuBarController: MenuBarController) {
        self.menuBarController = menuBarController
    }

    func update(state: SessionState) {
        let menuBarController = self.menuBarController
        Task { @MainActor in
            menuBarController?.setState(state)
        }
    }

    func showPermissionPrompt(_ snapshot: PermissionSnapshot) {
        let missing = missingPermissions(from: snapshot).joined(separator: ", ")
        let menuBarController = self.menuBarController
        Task { @MainActor in
            menuBarController?.setLastErrorMessage("missing permissions: \(missing)")
        }
    }

    func showError(_ error: FailureCode) {
        let menuBarController = self.menuBarController
        Task { @MainActor in
            menuBarController?.setLastErrorMessage(error.rawValue)
        }
        onError?(error)
    }

    func showPartialTranscript(_ text: String) {
        let menuBarController = self.menuBarController
        Task { @MainActor in
            menuBarController?.setPartialTranscript(text)
        }
    }

    private func missingPermissions(from snapshot: PermissionSnapshot) -> [String] {
        var missing: [String] = []
        if snapshot.microphone != .authorized {
            missing.append("microphone")
        }
        if snapshot.accessibility != .authorized {
            missing.append("accessibility")
        }
        if snapshot.inputMonitoring != .authorized {
            missing.append("input_monitoring")
        }
        return missing.isEmpty ? ["none"] : missing
    }
}

private final class MenuBarLogger: Logging {
    func log(_ message: String) {
        emit("metric \(message)")
    }
}

private func emit(_ line: String) {
    Swift.print(RuntimeLogFormatter.format(line))
}

private struct AppRewriteContextProvider: RewriteContextProviding {
    let mode: TranscriptRewriteMode

    func currentContext() -> RewriteContext {
        let app = NSWorkspace.shared.frontmostApplication
        return .init(
            frontmostAppBundleID: app?.bundleIdentifier,
            frontmostAppName: app?.localizedName,
            mode: mode.rawValue
        )
    }
}

private enum OverlayPreviewState: String {
    case idle
    case idleHover = "idle-hover"
    case listening
    case finalizing
    case error

    static func parse(_ rawValue: String) -> OverlayPreviewState? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch normalized {
        case "idle-hover", "idle_hover", "idlehover", "hover":
            return .idleHover
        default:
            return OverlayPreviewState(rawValue: normalized)
        }
    }

    var sessionState: SessionState {
        switch self {
        case .idle:
            return .idle
        case .idleHover:
            return .idle
        case .listening:
            return .listening
        case .finalizing:
            return .finalizing
        case .error:
            return .error(.engineError)
        }
    }
}

@MainActor
private final class RecordingOverlayController {
    var onStopRequested: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    private let panel: NSPanel
    private let overlayView: RecordingOverlayView
    private var promptText: String
    private let previewState: OverlayPreviewState?

    private var currentState: SessionState = .idle
    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0
    private var targetLevel: CGFloat = 0
    private var renderedLevel: CGFloat = 0
    private var screenObserver: NSObjectProtocol?
    private var hoverTimer: Timer?
    private var isDismissedUntilNextRecording = false

    init(promptText: String, previewState: OverlayPreviewState?) {
        self.promptText = promptText
        self.previewState = previewState
        self.overlayView = RecordingOverlayView(promptText: promptText)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = overlayView
        self.panel = panel

        overlayView.onDismissTap = { [weak self] in
            self?.handleDismissTap()
        }
        overlayView.onStopTap = { [weak self] in
            self?.handleStopTap()
        }
    }

    func start() {
        overlayView.updatePrompt(promptText)
        apply(state: .idle, animated: false)
        positionPanel()
        panel.orderFrontRegardless()
        attachScreenObserverIfNeeded()
        ensureHoverTimerIfNeeded()
        updateIdleHoverFromPointer()
    }

    func updatePromptText(_ text: String) {
        promptText = text
        overlayView.updatePrompt(text)
    }

    func stop() {
        animationTimer?.invalidate()
        animationTimer = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        panel.orderOut(nil)
    }

    func showPreview(state: OverlayPreviewState) {
        isDismissedUntilNextRecording = false
        currentState = state.sessionState
        apply(state: currentState, animated: false)
        overlayView.setIdleHover(state == .idleHover, animated: false)
        if state == .listening {
            targetLevel = 0.6
            ensureAnimationTimer()
        }
    }

    func update(state: SessionState) {
        guard previewState == nil else {
            return
        }
        currentState = state

        if state == .listening, isDismissedUntilNextRecording {
            isDismissedUntilNextRecording = false
            panel.orderFrontRegardless()
        }

        guard !isDismissedUntilNextRecording else {
            return
        }

        if state != .idle {
            overlayView.setIdleHover(false, animated: false)
        }
        apply(state: state, animated: true)
    }

    func updateAudioLevel(from frame: AudioFrame) {
        guard previewState == nil else {
            return
        }
        guard case .listening = currentState else {
            return
        }
        targetLevel = normalizedRMSLevel(from: frame)
        ensureAnimationTimer()
    }

    private func apply(state: SessionState, animated: Bool) {
        overlayView.transition(to: state, animated: animated)
        panel.ignoresMouseEvents = !overlayView.allowsActionClicks

        switch state {
        case .listening:
            ensureAnimationTimer()
        case .finalizing:
            targetLevel = max(targetLevel, 0.25)
            ensureAnimationTimer()
        case .idle, .inserting, .error:
            targetLevel = 0
            ensureAnimationTimer()
        }
    }

    private func ensureAnimationTimer() {
        guard animationTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func tick() {
        animationPhase += 0.30

        if previewState == .listening {
            targetLevel = 0.38 + 0.28 * ((sin(animationPhase * 0.68) + 1) * 0.5)
        }

        if case .finalizing = currentState {
            targetLevel *= 0.90
        } else if !isMeterActive(state: currentState) {
            targetLevel *= 0.75
        }

        renderedLevel += (targetLevel - renderedLevel) * 0.28
        overlayView.setMeter(level: renderedLevel, phase: animationPhase)

        if !isMeterActive(state: currentState), renderedLevel < 0.015, targetLevel < 0.015 {
            overlayView.setMeter(level: 0, phase: animationPhase)
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    private func isMeterActive(state: SessionState) -> Bool {
        switch state {
        case .listening, .finalizing:
            return true
        case .idle, .inserting, .error:
            return false
        }
    }

    private func normalizedRMSLevel(from frame: AudioFrame) -> CGFloat {
        guard !frame.samples.isEmpty else {
            return 0
        }

        var sumSquares: Double = 0
        for sample in frame.samples {
            let value = Double(sample)
            sumSquares += value * value
        }

        let meanSquare = sumSquares / Double(frame.samples.count)
        let rms = sqrt(meanSquare)
        return CGFloat(min(1, max(0, rms * 11)))
    }

    private func attachScreenObserverIfNeeded() {
        guard screenObserver == nil else {
            return
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.positionPanel()
            }
        }
    }

    private func ensureHoverTimerIfNeeded() {
        guard hoverTimer == nil else {
            return
        }
        guard previewState == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateIdleHoverFromPointer()
            }
        }
        hoverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateIdleHoverFromPointer() {
        guard !isDismissedUntilNextRecording else {
            return
        }
        guard case .idle = currentState else {
            overlayView.setIdleHover(false, animated: true)
            return
        }
        let pointer = NSEvent.mouseLocation
        let hoverArea = overlayView.idleHoverArea(in: panel)
        overlayView.setIdleHover(hoverArea.contains(pointer), animated: true)
    }

    private func handleDismissTap() {
        let canDismiss: Bool = {
            if case .listening = currentState {
                return true
            }
            if case .finalizing = currentState {
                return true
            }
            return false
        }()
        guard canDismiss else {
            return
        }
        isDismissedUntilNextRecording = true
        panel.ignoresMouseEvents = true
        panel.orderOut(nil)
        onDismissRequested?()
    }

    private func handleStopTap() {
        guard case .listening = currentState else {
            return
        }
        onStopRequested?()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        let x = visibleFrame.midX - (size.width / 2)
        let y = visibleFrame.minY + 8
        let safeX = max(visibleFrame.minX + 20, min(x, visibleFrame.maxX - size.width - 20))
        panel.setFrameOrigin(NSPoint(x: safeX, y: y))
    }
}

private final class RecordingOverlayView: NSView {
    var onDismissTap: (() -> Void)?
    var onStopTap: (() -> Void)?

    private let promptPill = OverlayCapsuleView()
    private let promptLabel = NSTextField(labelWithString: "")
    private let activityPill = OverlayCapsuleView()
    private let dismissBadge = OverlayBadgeView(symbolName: "xmark")
    private let stopBadge = OverlayBadgeView(symbolName: "stop.fill")
    private let meterView = OverlayMeterWaveView()

    private var activityWidthConstraint: NSLayoutConstraint?
    private var activityHeightConstraint: NSLayoutConstraint?
    private var meterWidthConstraint: NSLayoutConstraint?
    private var meterHeightConstraint: NSLayoutConstraint?
    private var promptWidthConstraint: NSLayoutConstraint?
    private var badgePlacementConstraints: [NSLayoutConstraint] = []
    private var currentState: SessionState = .idle
    private var isIdleHovering = false
    private var promptText: String

    init(promptText: String) {
        self.promptText = promptText
        super.init(frame: .zero)
        setupView()
        transition(to: .idle, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var allowsActionClicks: Bool {
        !dismissBadge.isHidden && !stopBadge.isHidden
    }

    func updatePrompt(_ text: String) {
        promptText = text
        if !promptPill.isHidden {
            promptLabel.stringValue = text
        }
    }

    func transition(to state: SessionState, animated: Bool) {
        currentState = state
        let style = style(for: state)
        apply(style: style, animated: animated)
    }

    func setIdleHover(_ isHovering: Bool, animated: Bool) {
        guard self.isIdleHovering != isHovering else {
            return
        }
        self.isIdleHovering = isHovering
        guard case .idle = currentState else {
            return
        }
        apply(style: style(for: .idle), animated: animated)
    }

    func idleHoverArea(in window: NSWindow) -> NSRect {
        let localArea = activityPill.frame.insetBy(dx: -18, dy: -12)
        let windowRect = convert(localArea, to: nil)
        return window.convertToScreen(windowRect)
    }

    func setMeter(level: CGFloat, phase: CGFloat) {
        guard !meterView.isHidden else {
            activityPill.layer?.shadowOpacity = 0
            return
        }
        meterView.set(level: level, phase: phase)

        let glow = Float(0.06 + (min(1, max(0, level)) * 0.22))
        activityPill.layer?.shadowOpacity = meterView.isActive ? glow : 0
    }

    private func promptWidth(for message: String) -> CGFloat {
        let font = promptLabel.font ?? NSFont.systemFont(ofSize: 14, weight: .semibold)
        let measured = (message as NSString).size(withAttributes: [.font: font]).width
        let padded = ceil(measured + 44)
        return min(500, max(280, padded))
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        promptPill.translatesAutoresizingMaskIntoConstraints = false
        promptPill.apply(fill: NSColor.black.withAlphaComponent(0.76), border: NSColor.white.withAlphaComponent(0.18))
        addSubview(promptPill)

        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.stringValue = promptText
        promptLabel.textColor = NSColor.white.withAlphaComponent(0.82)
        promptLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        promptLabel.alignment = .center
        promptLabel.lineBreakMode = .byTruncatingTail
        promptPill.addSubview(promptLabel)

        activityPill.translatesAutoresizingMaskIntoConstraints = false
        activityPill.apply(fill: NSColor.black.withAlphaComponent(0.78), border: NSColor.white.withAlphaComponent(0.18))
        addSubview(activityPill)

        dismissBadge.translatesAutoresizingMaskIntoConstraints = false
        stopBadge.translatesAutoresizingMaskIntoConstraints = false
        meterView.translatesAutoresizingMaskIntoConstraints = false

        activityPill.addSubview(dismissBadge)
        activityPill.addSubview(meterView)
        activityPill.addSubview(stopBadge)

        dismissBadge.setStyle(
            fill: NSColor.white.withAlphaComponent(0.11),
            symbolColor: NSColor.white.withAlphaComponent(0.62)
        )
        stopBadge.setStyle(
            fill: NSColor.systemRed.withAlphaComponent(0.70),
            symbolColor: NSColor.white.withAlphaComponent(0.86)
        )
        dismissBadge.onTap = { [weak self] in
            self?.onDismissTap?()
        }
        stopBadge.onTap = { [weak self] in
            self?.onStopTap?()
        }

        activityWidthConstraint = activityPill.widthAnchor.constraint(equalToConstant: 88)
        activityWidthConstraint?.isActive = true
        activityHeightConstraint = activityPill.heightAnchor.constraint(equalToConstant: 24)
        activityHeightConstraint?.isActive = true
        meterWidthConstraint = meterView.widthAnchor.constraint(equalToConstant: 52)
        meterWidthConstraint?.isActive = true
        meterHeightConstraint = meterView.heightAnchor.constraint(equalToConstant: 8)
        meterHeightConstraint?.isActive = true
        promptWidthConstraint = promptPill.widthAnchor.constraint(equalToConstant: promptWidth(for: promptText))
        promptWidthConstraint?.isActive = true

        badgePlacementConstraints = [
            dismissBadge.centerYAnchor.constraint(equalTo: activityPill.centerYAnchor),
            dismissBadge.trailingAnchor.constraint(equalTo: meterView.leadingAnchor, constant: -10),
            dismissBadge.leadingAnchor.constraint(greaterThanOrEqualTo: activityPill.leadingAnchor, constant: 8),
            stopBadge.centerYAnchor.constraint(equalTo: activityPill.centerYAnchor),
            stopBadge.leadingAnchor.constraint(equalTo: meterView.trailingAnchor, constant: 10),
            stopBadge.trailingAnchor.constraint(lessThanOrEqualTo: activityPill.trailingAnchor, constant: -8)
        ]

        NSLayoutConstraint.activate([
            promptPill.centerXAnchor.constraint(equalTo: centerXAnchor),
            promptPill.heightAnchor.constraint(equalToConstant: 50),
            promptPill.bottomAnchor.constraint(equalTo: activityPill.topAnchor, constant: -8),

            promptLabel.leadingAnchor.constraint(equalTo: promptPill.leadingAnchor, constant: 14),
            promptLabel.trailingAnchor.constraint(equalTo: promptPill.trailingAnchor, constant: -14),
            promptLabel.centerYAnchor.constraint(equalTo: promptPill.centerYAnchor),

            activityPill.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityPill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            meterView.centerXAnchor.constraint(equalTo: activityPill.centerXAnchor),
            meterView.centerYAnchor.constraint(equalTo: activityPill.centerYAnchor),

            dismissBadge.widthAnchor.constraint(equalToConstant: 26),
            dismissBadge.heightAnchor.constraint(equalToConstant: 26),

            stopBadge.widthAnchor.constraint(equalToConstant: 26),
            stopBadge.heightAnchor.constraint(equalToConstant: 26),
        ])
    }

    private func apply(style: OverlayStyle, animated: Bool) {
        promptLabel.stringValue = style.promptMessage ?? promptText
        promptLabel.textColor = style.promptTextColor
        promptPill.isHidden = !style.showPrompt
        dismissBadge.isHidden = !style.showBadges
        stopBadge.isHidden = !style.showBadges
        meterView.isHidden = !style.showMeter
        meterView.setActive(style.meterActive)

        dismissBadge.setStyle(fill: style.leftBadgeFill, symbolColor: style.leftBadgeSymbol)
        stopBadge.setStyle(fill: style.rightBadgeFill, symbolColor: style.rightBadgeSymbol)
        activityPill.apply(fill: style.activityFill, border: style.activityBorder)
        activityPill.layer?.shadowColor = style.glowColor.cgColor
        activityPill.layer?.shadowRadius = style.glowRadius

        guard
            let activityWidthConstraint,
            let activityHeightConstraint,
            let meterWidthConstraint,
            let meterHeightConstraint,
            let promptWidthConstraint
        else {
            return
        }

        if style.showBadges {
            NSLayoutConstraint.activate(badgePlacementConstraints)
        } else {
            NSLayoutConstraint.deactivate(badgePlacementConstraints)
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                activityWidthConstraint.animator().constant = style.activityWidth
                activityHeightConstraint.animator().constant = style.activityHeight
                meterWidthConstraint.animator().constant = style.meterWidth
                meterHeightConstraint.animator().constant = style.meterHeight
                promptWidthConstraint.animator().constant = self.promptWidth(for: style.promptMessage ?? self.promptText)
                self.layoutSubtreeIfNeeded()
            }
        } else {
            activityWidthConstraint.constant = style.activityWidth
            activityHeightConstraint.constant = style.activityHeight
            meterWidthConstraint.constant = style.meterWidth
            meterHeightConstraint.constant = style.meterHeight
            promptWidthConstraint.constant = promptWidth(for: style.promptMessage ?? promptText)
            layoutSubtreeIfNeeded()
        }
    }

    private func style(for state: SessionState) -> OverlayStyle {
        switch state {
        case .idle:
            if isIdleHovering {
                return OverlayStyle(
                    showPrompt: true,
                    promptMessage: promptText,
                    promptTextColor: NSColor.white.withAlphaComponent(0.80),
                    showBadges: false,
                    showMeter: true,
                    meterActive: false,
                    activityWidth: 96,
                    activityHeight: 26,
                    meterWidth: 56,
                    meterHeight: 10,
                    leftBadgeFill: NSColor.white.withAlphaComponent(0.10),
                    leftBadgeSymbol: NSColor.white.withAlphaComponent(0.60),
                    rightBadgeFill: NSColor.systemRed.withAlphaComponent(0.66),
                    rightBadgeSymbol: NSColor.white.withAlphaComponent(0.84),
                    activityFill: NSColor.black.withAlphaComponent(0.74),
                    activityBorder: NSColor.white.withAlphaComponent(0.16),
                    glowColor: NSColor.systemPink,
                    glowRadius: 10
                )
            }
            return OverlayStyle(
                showPrompt: false,
                promptMessage: promptText,
                promptTextColor: NSColor.white.withAlphaComponent(0.80),
                showBadges: false,
                showMeter: false,
                meterActive: false,
                activityWidth: 40,
                activityHeight: 8,
                meterWidth: 34,
                meterHeight: 8,
                leftBadgeFill: NSColor.white.withAlphaComponent(0.10),
                leftBadgeSymbol: NSColor.white.withAlphaComponent(0.60),
                rightBadgeFill: NSColor.systemRed.withAlphaComponent(0.66),
                rightBadgeSymbol: NSColor.white.withAlphaComponent(0.84),
                activityFill: NSColor.white.withAlphaComponent(0.28),
                activityBorder: NSColor.white.withAlphaComponent(0.34),
                glowColor: NSColor.systemPink,
                glowRadius: 0
            )
        case .listening:
            return OverlayStyle(
                showPrompt: false,
                promptMessage: nil,
                promptTextColor: NSColor.white.withAlphaComponent(0.80),
                showBadges: true,
                showMeter: true,
                meterActive: true,
                activityWidth: 160,
                activityHeight: 30,
                meterWidth: 76,
                meterHeight: 14,
                leftBadgeFill: NSColor.white.withAlphaComponent(0.10),
                leftBadgeSymbol: NSColor.white.withAlphaComponent(0.60),
                rightBadgeFill: NSColor.systemRed.withAlphaComponent(0.68),
                rightBadgeSymbol: NSColor.white.withAlphaComponent(0.84),
                activityFill: NSColor.black.withAlphaComponent(0.76),
                activityBorder: NSColor.white.withAlphaComponent(0.16),
                glowColor: NSColor.systemPink,
                glowRadius: 10
            )
        case .finalizing:
            return OverlayStyle(
                showPrompt: false,
                promptMessage: nil,
                promptTextColor: NSColor.white.withAlphaComponent(0.80),
                showBadges: true,
                showMeter: true,
                meterActive: true,
                activityWidth: 150,
                activityHeight: 28,
                meterWidth: 70,
                meterHeight: 12,
                leftBadgeFill: NSColor.white.withAlphaComponent(0.10),
                leftBadgeSymbol: NSColor.white.withAlphaComponent(0.60),
                rightBadgeFill: NSColor.systemOrange.withAlphaComponent(0.66),
                rightBadgeSymbol: NSColor.white.withAlphaComponent(0.84),
                activityFill: NSColor.black.withAlphaComponent(0.76),
                activityBorder: NSColor.white.withAlphaComponent(0.16),
                glowColor: NSColor.systemOrange,
                glowRadius: 9
            )
        case .inserting:
            return OverlayStyle(
                showPrompt: false,
                promptMessage: nil,
                promptTextColor: NSColor.white.withAlphaComponent(0.80),
                showBadges: false,
                showMeter: false,
                meterActive: false,
                activityWidth: 40,
                activityHeight: 8,
                meterWidth: 34,
                meterHeight: 8,
                leftBadgeFill: NSColor.white.withAlphaComponent(0.10),
                leftBadgeSymbol: NSColor.white.withAlphaComponent(0.60),
                rightBadgeFill: NSColor.systemRed.withAlphaComponent(0.66),
                rightBadgeSymbol: NSColor.white.withAlphaComponent(0.84),
                activityFill: NSColor.white.withAlphaComponent(0.28),
                activityBorder: NSColor.white.withAlphaComponent(0.34),
                glowColor: NSColor.systemPink,
                glowRadius: 0
            )
        case .error:
            return OverlayStyle(
                showPrompt: false,
                promptMessage: "Dictation failed. Try again.",
                promptTextColor: NSColor.systemOrange.withAlphaComponent(0.80),
                showBadges: false,
                showMeter: false,
                meterActive: false,
                activityWidth: 40,
                activityHeight: 8,
                meterWidth: 34,
                meterHeight: 8,
                leftBadgeFill: NSColor.white.withAlphaComponent(0.10),
                leftBadgeSymbol: NSColor.white.withAlphaComponent(0.60),
                rightBadgeFill: NSColor.systemRed.withAlphaComponent(0.66),
                rightBadgeSymbol: NSColor.white.withAlphaComponent(0.84),
                activityFill: NSColor.white.withAlphaComponent(0.28),
                activityBorder: NSColor.systemOrange.withAlphaComponent(0.32),
                glowColor: NSColor.systemOrange,
                glowRadius: 0
            )
        }
    }
}

private struct OverlayStyle {
    let showPrompt: Bool
    let promptMessage: String?
    let promptTextColor: NSColor
    let showBadges: Bool
    let showMeter: Bool
    let meterActive: Bool
    let activityWidth: CGFloat
    let activityHeight: CGFloat
    let meterWidth: CGFloat
    let meterHeight: CGFloat
    let leftBadgeFill: NSColor
    let leftBadgeSymbol: NSColor
    let rightBadgeFill: NSColor
    let rightBadgeSymbol: NSColor
    let activityFill: NSColor
    let activityBorder: NSColor
    let glowColor: NSColor
    let glowRadius: CGFloat
}

private final class OverlayCapsuleView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerCurve = .circular
        layer?.borderWidth = 1
        layer?.shadowOffset = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(fill: NSColor, border: NSColor) {
        layer?.backgroundColor = fill.cgColor
        layer?.borderColor = border.cgColor
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = max(1, bounds.height * 0.5)
    }
}

private final class OverlayBadgeView: NSView {
    var onTap: (() -> Void)?

    private let imageView: NSImageView

    init(symbolName: String) {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        self.imageView = NSImageView(image: image ?? NSImage())
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = 14

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        imageView.contentTintColor = NSColor.white
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStyle(fill: NSColor, symbolColor: NSColor) {
        layer?.backgroundColor = fill.cgColor
        imageView.contentTintColor = symbolColor
    }

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }
}

private final class OverlayMeterWaveView: NSView {
    private(set) var isActive = false
    private var level: CGFloat = 0
    private var phase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        if !isActive {
            level = 0
        }
        needsDisplay = true
    }

    func set(level: CGFloat, phase: CGFloat) {
        self.level = min(1, max(0, level))
        self.phase = phase
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 4, bounds.height > 4 else {
            return
        }

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let centerY = rect.midY
        let clampedLevel = min(1, max(0, level))
        let baselineAlpha: CGFloat = isActive ? 0.25 : 0.18

        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: centerY))
        baseline.line(to: NSPoint(x: rect.maxX, y: centerY))
        baseline.lineWidth = 1
        NSColor.white.withAlphaComponent(baselineAlpha).setStroke()
        baseline.stroke()

        let maxAmplitude = rect.height * 0.45
        let primaryAmplitude = isActive ? maxAmplitude * (0.22 + (clampedLevel * 0.78)) : maxAmplitude * 0.14
        let secondaryAmplitude = primaryAmplitude * 0.58
        let cycleCount = 1.6 + (clampedLevel * 1.7)
        let steps = max(36, Int(rect.width * 2))

        let primaryPath = NSBezierPath()
        let secondaryPath = NSBezierPath()
        for step in 0..<steps {
            let progress = CGFloat(step) / CGFloat(max(1, steps - 1))
            let x = rect.minX + (rect.width * progress)
            let envelope = max(0.22, sin(progress * .pi))
            let angle = (progress * cycleCount * .pi * 2) + (phase * 1.25)

            let primaryY = centerY + sin(angle) * primaryAmplitude * envelope
            let secondaryY = centerY + sin((angle * 1.35) + 1.2) * secondaryAmplitude * envelope

            let primaryPoint = NSPoint(x: x, y: primaryY)
            let secondaryPoint = NSPoint(x: x, y: secondaryY)
            if step == 0 {
                primaryPath.move(to: primaryPoint)
                secondaryPath.move(to: secondaryPoint)
            } else {
                primaryPath.line(to: primaryPoint)
                secondaryPath.line(to: secondaryPoint)
            }
        }

        primaryPath.lineJoinStyle = .round
        primaryPath.lineCapStyle = .round
        primaryPath.lineWidth = isActive ? 2.2 : 1.6
        NSColor.white.withAlphaComponent(isActive ? 0.78 : 0.34).setStroke()
        primaryPath.stroke()

        secondaryPath.lineJoinStyle = .round
        secondaryPath.lineCapStyle = .round
        secondaryPath.lineWidth = isActive ? 1.6 : 1.2
        NSColor.white.withAlphaComponent(isActive ? 0.42 : 0.22).setStroke()
        secondaryPath.stroke()
    }
}

private enum FeedbackSoundID: CaseIterable {
    case recordingStart
    case recordingStop

    var volume: Float {
        switch self {
        case .recordingStart:
            return 0.62
        case .recordingStop:
            return 0.55
        }
    }

    var asset: FeedbackSoundAsset {
        switch self {
        case .recordingStart:
            return .recordingStart
        case .recordingStop:
            return .recordingStop
        }
    }
}

@MainActor
private enum FeedbackSoundLibrary {
    private static var cachedSounds: [FeedbackSoundID: NSSound] = [:]

    static func preloadAll() {
        for id in FeedbackSoundID.allCases {
            _ = loadSound(for: id)
        }
    }

    static func resourceURL(for id: FeedbackSoundID) -> URL? {
        id.asset.resourceURL
    }

    static func loadSound(for id: FeedbackSoundID) -> NSSound? {
        if let cached = cachedSounds[id] {
            return cached
        }

        guard let url = resourceURL(for: id) else {
            return nil
        }

        guard let sound = NSSound(contentsOf: url, byReference: true) else {
            return nil
        }
        sound.volume = id.volume
        cachedSounds[id] = sound
        return sound
    }
}


private final class AppFeedbackPresenter: FeedbackPresenting {
    private let onRecordingStarted: (@MainActor () -> Void)?
    private let onRecordingStopped: (@MainActor () -> Void)?

    init(
        onRecordingStarted: (@MainActor () -> Void)? = nil,
        onRecordingStopped: (@MainActor () -> Void)? = nil
    ) {
        self.onRecordingStarted = onRecordingStarted
        self.onRecordingStopped = onRecordingStopped
        Task { @MainActor in
            FeedbackSoundLibrary.preloadAll()
        }
    }

    func recordingDidStart() {
        let onRecordingStarted = self.onRecordingStarted
        Task { @MainActor in
            onRecordingStarted?()
            Self.playBestEffortCue(soundID: .recordingStart)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }

    func recordingDidStop() {
        let onRecordingStopped = self.onRecordingStopped
        Task { @MainActor in
            onRecordingStopped?()
            Self.playBestEffortCue(soundID: .recordingStop)
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }

    @MainActor
    private static func playBestEffortCue(soundID: FeedbackSoundID) {
        if let sound = FeedbackSoundLibrary.loadSound(for: soundID) {
            sound.stop()
            sound.play()
            return
        }
        NSSound.beep()
    }
}

#else

@main
struct MurmurMenuBarApp {
    static func main() {
        Swift.print("MurmurMenuBarApp requires AppKit/macOS.")
    }
}

#endif
