import Foundation

#if canImport(AppKit)
import AppKit
import DictationAppCore

@main
struct MurmurMenuBarApp {
    static func main() {
        let arguments = Arguments.parse(CommandLine.arguments)
        if let warning = arguments.shortcutWarning {
            Swift.print("warning=\(warning)")
        }
        let menuBarController = MenuBarController()
        let runtime = MenuBarRuntime(
            menuBarController: menuBarController,
            model: arguments.model,
            pythonBinary: arguments.pythonBinary,
            scriptPath: arguments.scriptPath,
            hotkeyShortcuts: arguments.hotkeyShortcuts
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
    let hotkeyShortcuts: [HotkeyShortcut]
    let shortcutWarning: String?

    static func parse(_ rawArgs: [String]) -> Arguments {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let environment = ProcessInfo.processInfo.environment
        let shortcutIdentifier = value(after: "--shortcut", in: rawArgs)
        let shortcutResolution = resolveHotkeyShortcuts(shortcutIdentifier: shortcutIdentifier)

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
            hotkeyShortcuts: shortcutResolution.shortcuts,
            shortcutWarning: shortcutResolution.warning
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
}

private final class MenuBarRuntime {
    private let menuBarController: MenuBarController
    private let statusUI: MenuBarStatusUI
    private let logger: MenuBarLogger
    private let audioCapture: AudioCapture
    private let asrEngine: MoonshineProcessASREngine
    private let orchestrator: SessionOrchestrator
    private let hotkeyController: HotkeyController
    private let bridge: HotkeySessionBridge

    init(
        menuBarController: MenuBarController,
        model: String,
        pythonBinary: String,
        scriptPath: String,
        hotkeyShortcuts: [HotkeyShortcut]
    ) {
        self.menuBarController = menuBarController

        let statusUI = MenuBarStatusUI(menuBarController: menuBarController)
        let logger = MenuBarLogger()
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
            fieldWriter: FocusedFieldWriter(),
            statusUI: statusUI,
            transcriptHistory: transcriptHistory,
            logger: logger
        )
        let hotkeyController = HotkeyController(shortcuts: hotkeyShortcuts)
        let bridge = HotkeySessionBridge(
            hotkeyController: hotkeyController,
            sessionEventHandler: orchestrator
        )

        self.statusUI = statusUI
        self.logger = logger
        self.audioCapture = audioCapture
        self.asrEngine = asrEngine
        self.orchestrator = orchestrator
        self.hotkeyController = hotkeyController
        self.bridge = bridge

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
    }

    func start() {
        let orchestrator = self.orchestrator
        let menuBarController = self.menuBarController
        let hotkeyController = self.hotkeyController
        let logger = self.logger

        audioCapture.onFrame = { frame in
            orchestrator.handle(.audioFrame(frame))
        }
        audioCapture.onError = { error in
            Task { @MainActor in
                menuBarController.setLastErrorMessage("audio: \(error.localizedDescription)")
            }
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
        logger.log("menu_bar_stopped")
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
        Swift.print("metric \(message)")
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
