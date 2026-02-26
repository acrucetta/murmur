import Foundation
import DictationAppCore
import TermKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private enum TermKitShortcutSelection {
    case keep
    case set(String)
    case reset
}

private enum TermKitAPIKeySelection {
    case keep
    case set(String)
    case clear
}

private enum TermKitMicrophoneSelection {
    case keep
    case set(String)
    case reset
}

private struct TermKitConfigState {
    let currentShortcut: String
    let currentRewriteMode: String
    let currentModel: String
    let currentPauseMediaWhileRecording: Bool
    let currentMicrophone: String?
    let currentSmartRewriteThreshold: Int
    let apiKeyStored: Bool
    let apiKeySource: String
}

private struct TermKitConfigStore {
    let configDir: String
    let defaultShortcut: String
    let defaultRewriteMode: String
    let defaultOpenRouterModel: String
    let defaultPauseMediaWhileRecording: Bool
    let defaultSmartRewriteThreshold: Int

    private var shortcutPath: String { "\(configDir)/shortcut.txt" }
    private var rewriteModePath: String { "\(configDir)/rewrite_mode.txt" }
    private var modelPath: String { "\(configDir)/openrouter_model.txt" }
    private var pauseMediaPath: String { "\(configDir)/pause_media_while_recording.txt" }
    private var microphonePath: String { "\(configDir)/microphone.txt" }
    private var smartRewriteThresholdPath: String { "\(configDir)/smart_rewrite_threshold.txt" }
    private var apiKeyPath: String { "\(configDir)/openrouter_api_key.txt" }

    func load() -> TermKitConfigState {
        let shortcut = readValue(path: shortcutPath) ?? defaultShortcut
        let rewriteMode = normalizeRewriteMode(readValue(path: rewriteModePath))
            ?? normalizeRewriteMode(defaultRewriteMode)
            ?? "smart"
        let model = readValue(path: modelPath) ?? defaultOpenRouterModel
        let pauseMediaWhileRecording = normalizeBoolean(readValue(path: pauseMediaPath)) ?? defaultPauseMediaWhileRecording
        let microphone = readValue(path: microphonePath)
        let smartRewriteThreshold = normalizeInt(readValue(path: smartRewriteThresholdPath)) ?? defaultSmartRewriteThreshold
        let apiKeyStored = (readValue(path: apiKeyPath) ?? "").isEmpty == false
        let apiKeySource = apiKeyStored ? "file:\(apiKeyPath)" : "unset"

        return .init(
            currentShortcut: shortcut,
            currentRewriteMode: rewriteMode,
            currentModel: model,
            currentPauseMediaWhileRecording: pauseMediaWhileRecording,
            currentMicrophone: microphone,
            currentSmartRewriteThreshold: smartRewriteThreshold,
            apiKeyStored: apiKeyStored,
            apiKeySource: apiKeySource
        )
    }
    func persist(
        shortcut: TermKitShortcutSelection,
        rewriteMode: String,
        openRouterModel: String?,
        pauseMediaWhileRecording: Bool,
        microphone: TermKitMicrophoneSelection,
        smartRewriteThreshold: Int,
        apiKey: TermKitAPIKeySelection
    ) throws {
        try ensureConfigDir()
        try writeValue(path: rewriteModePath, value: rewriteMode)
        try writeValue(path: pauseMediaPath, value: pauseMediaWhileRecording ? "true" : "false")
        try writeValue(path: smartRewriteThresholdPath, value: String(smartRewriteThreshold))

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

        switch microphone {
        case .keep:
            break
        case .set(let value):
            try writeValue(path: microphonePath, value: value)
        case .reset:
            try removeFile(path: microphonePath)
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
            throw TermKitWizardError.invalid("failed to encode value for \(path)")
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

    private func normalizeBoolean(_ raw: String?) -> Bool? {
        guard let raw else {
            return nil
        }

        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }

    private func normalizeInt(_ raw: String?) -> Int? {
        guard let raw else {
            return nil
        }
        return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private enum TermKitWizardError: Error {
    case invalid(String)
}

private struct TermKitWizardTheme {
    let window: ColorScheme
    let textInput: ColorScheme
    let actionButton: ColorScheme
    let dialog: ColorScheme

    static func make() -> TermKitWizardTheme {
        let window = ColorScheme(
            normal: Application.makeAttribute(fore: .gray, back: .black),
            focus: Application.makeAttribute(fore: .white, back: .darkGray),
            hotNormal: Application.makeAttribute(fore: .brightMagenta, back: .black),
            hotFocus: Application.makeAttribute(fore: .brightYellow, back: .darkGray)
        )

        let textInput = ColorScheme(
            normal: Application.makeAttribute(fore: .white, back: .darkGray),
            focus: Application.makeAttribute(fore: .black, back: .brightYellow),
            hotNormal: Application.makeAttribute(fore: .brightMagenta, back: .darkGray),
            hotFocus: Application.makeAttribute(fore: .brightMagenta, back: .brightYellow)
        )

        let actionButton = ColorScheme(
            normal: Application.makeAttribute(fore: .brightCyan, back: .black),
            focus: Application.makeAttribute(fore: .black, back: .brightMagenta),
            hotNormal: Application.makeAttribute(fore: .brightYellow, back: .black),
            hotFocus: Application.makeAttribute(fore: .brightYellow, back: .brightMagenta)
        )

        let dialog = ColorScheme(
            normal: Application.makeAttribute(fore: .gray, back: .black),
            focus: Application.makeAttribute(fore: .white, back: .darkGray),
            hotNormal: Application.makeAttribute(fore: .brightMagenta, back: .black),
            hotFocus: Application.makeAttribute(fore: .brightYellow, back: .darkGray)
        )

        return .init(window: window, textInput: textInput, actionButton: actionButton, dialog: dialog)
    }
}

private final class TermKitConfigWizardApp {
    private let store: TermKitConfigStore
    private let initialState: TermKitConfigState

    private var shortcutSelection: TermKitShortcutSelection = .keep
    private var microphoneSelection: TermKitMicrophoneSelection = .keep
    private var rewriteMode: String
    private var selectedModel: String
    private var pauseMediaWhileRecording: Bool
    private var smartRewriteThreshold: Int

    private let rewriteModeValueLabel = Label("")
    private let modelValueLabel = Label("")
    private let hotkeyValueLabel = Label("")
    private let microphoneValueLabel = Label("")
    private let pauseMediaValueLabel = Label("")
    private let smartRewriteThresholdValueLabel = Label("")
    private let apiKeySourceLabel = Label("")
    private let apiKeyField = TextField("")
    private let clearAPIKeyCheckbox = Checkbox("Clear stored API key")
    private var theme = TermKitWizardTheme(
        window: .fallback,
        textInput: .fallback,
        actionButton: .fallback,
        dialog: .fallback
    )

    init(store: TermKitConfigStore) {
        self.store = store
        self.initialState = store.load()
        self.rewriteMode = initialState.currentRewriteMode
        self.selectedModel = initialState.currentModel
        self.pauseMediaWhileRecording = initialState.currentPauseMediaWhileRecording
        self.smartRewriteThreshold = initialState.currentSmartRewriteThreshold
    }

    func run() -> Never {
        Application.prepare()
        theme = TermKitWizardTheme.make()

        let window = Window("Murmur Config", internalPadding: 0)
        window.fill()
        window.colorScheme = theme.window
        window.closeClicked = { _ in
            self.cancelAndExit()
        }

        let bannerHeader = Label(
            """
             __  __ _   _ ____  __  __ _   _ ____                  ⢀⡀
            |  \\/  | | | |  _ \\|  \\/  | | | |  _ \\            ⢴⡾⢿⣿⣷
            | |\\/| | | | | |_) | |\\/| | | | | |_) |         ⣴⠗⠀⠀⠀⠹⣿⣇
            | |  | | |_| |  _ <| |  | | |_| |  _ <         ⠈⠀⠀⠀⠀⠀⢻⠻⡆
            |_|  |_|\\___/|_| \\_\\_|  |_|\\___/|_| \\_\\                  ⢳⠀⠠⠄
                                                                    ⠸⣧⠀⢴⠄
            """
        )
        bannerHeader.x = Pos.at(2)
        bannerHeader.y = Pos.at(1)

        let intro = Label("Use Tab/arrows and Enter to navigate. Ctrl-C cancels.")
        intro.x = Pos.at(2)
        intro.y = Pos.at(8)

        let configDirLine = Label("Config dir: \(store.configDir)")
        configDirLine.x = Pos.at(2)
        configDirLine.y = Pos.at(9)

        let rewriteModeTitle = Label("Rewrite mode:")
        rewriteModeTitle.x = Pos.at(2)
        rewriteModeTitle.y = Pos.at(11)

        rewriteModeValueLabel.x = Pos.at(24)
        rewriteModeValueLabel.y = Pos.top(of: rewriteModeTitle)
        rewriteModeValueLabel.width = Dim.sized(42)

        let rewriteModeButton = Button("_Choose")
        rewriteModeButton.colorScheme = theme.actionButton
        rewriteModeButton.x = Pos.right(of: rewriteModeValueLabel) + 1
        rewriteModeButton.y = Pos.top(of: rewriteModeTitle)
        rewriteModeButton.clicked = { _ in
            self.chooseRewriteMode()
        }

        let modelTitle = Label("OpenRouter model:")
        modelTitle.x = Pos.at(2)
        modelTitle.y = Pos.at(13)

        modelValueLabel.x = Pos.at(24)
        modelValueLabel.y = Pos.top(of: modelTitle)
        modelValueLabel.width = Dim.sized(42)

        let modelButton = Button("_Choose")
        modelButton.colorScheme = theme.actionButton
        modelButton.x = Pos.right(of: modelValueLabel) + 1
        modelButton.y = Pos.top(of: modelTitle)
        modelButton.clicked = { _ in
            self.chooseModel()
        }

        let hotkeyTitle = Label("Primary hotkey:")
        hotkeyTitle.x = Pos.at(2)
        hotkeyTitle.y = Pos.at(15)

        hotkeyValueLabel.x = Pos.at(24)
        hotkeyValueLabel.y = Pos.top(of: hotkeyTitle)
        hotkeyValueLabel.width = Dim.sized(42)

        let hotkeyButton = Button("_Choose")
        hotkeyButton.colorScheme = theme.actionButton
        hotkeyButton.x = Pos.right(of: hotkeyValueLabel) + 1
        hotkeyButton.y = Pos.top(of: hotkeyTitle)
        hotkeyButton.clicked = { _ in
            self.chooseHotkey()
        }

        let microphoneTitle = Label("Microphone input:")
        microphoneTitle.x = Pos.at(2)
        microphoneTitle.y = Pos.at(17)

        microphoneValueLabel.x = Pos.at(24)
        microphoneValueLabel.y = Pos.top(of: microphoneTitle)
        microphoneValueLabel.width = Dim.sized(42)

        let microphoneButton = Button("_Choose")
        microphoneButton.colorScheme = theme.actionButton
        microphoneButton.x = Pos.right(of: microphoneValueLabel) + 1
        microphoneButton.y = Pos.top(of: microphoneTitle)
        microphoneButton.clicked = { _ in
            self.chooseMicrophone()
        }

        let pauseMediaTitle = Label("Pause media while recording:")
        pauseMediaTitle.x = Pos.at(2)
        pauseMediaTitle.y = Pos.at(19)

        pauseMediaValueLabel.x = Pos.at(32)
        pauseMediaValueLabel.y = Pos.top(of: pauseMediaTitle)
        pauseMediaValueLabel.width = Dim.sized(34)

        let pauseMediaButton = Button("_Choose")
        pauseMediaButton.colorScheme = theme.actionButton
        pauseMediaButton.x = Pos.right(of: pauseMediaValueLabel) + 1
        pauseMediaButton.y = Pos.top(of: pauseMediaTitle)
        pauseMediaButton.clicked = { _ in
            self.choosePauseMediaMode()
        }

        let smartRewriteThresholdTitle = Label("Smart rewrite threshold:")
        smartRewriteThresholdTitle.x = Pos.at(2)
        smartRewriteThresholdTitle.y = Pos.at(21)

        smartRewriteThresholdValueLabel.x = Pos.at(32)
        smartRewriteThresholdValueLabel.y = Pos.top(of: smartRewriteThresholdTitle)
        smartRewriteThresholdValueLabel.width = Dim.sized(34)

        let smartRewriteThresholdButton = Button("_Choose")
        smartRewriteThresholdButton.colorScheme = theme.actionButton
        smartRewriteThresholdButton.x = Pos.right(of: smartRewriteThresholdValueLabel) + 1
        smartRewriteThresholdButton.y = Pos.top(of: smartRewriteThresholdTitle)
        smartRewriteThresholdButton.clicked = { _ in
            self.chooseSmartRewriteThreshold()
        }

        let apiKeyTitle = Label("OpenRouter API key (leave blank to keep current):")
        apiKeyTitle.x = Pos.at(2)
        apiKeyTitle.y = Pos.at(23)

        apiKeySourceLabel.x = Pos.at(2)
        apiKeySourceLabel.y = Pos.at(24)

        apiKeyField.x = Pos.at(2)
        apiKeyField.y = Pos.at(25)
        apiKeyField.width = Dim.sized(61)
        apiKeyField.secret = true
        apiKeyField.colorScheme = theme.textInput

        let testAPIKeyButton = Button("_Test")
        testAPIKeyButton.colorScheme = theme.actionButton
        testAPIKeyButton.x = Pos.right(of: apiKeyField) + 1
        testAPIKeyButton.y = Pos.top(of: apiKeyField)
        testAPIKeyButton.clicked = { _ in
            self.testAPIKey()
        }

        clearAPIKeyCheckbox.x = Pos.at(2)
        clearAPIKeyCheckbox.y = Pos.at(26)
        clearAPIKeyCheckbox.colorScheme = theme.actionButton

        let saveButton = Button("_Save")
        saveButton.isDefault = true
        saveButton.colorScheme = theme.actionButton
        saveButton.x = Pos.at(2)
        saveButton.y = Pos.at(28)
        saveButton.clicked = { _ in
            self.saveAndExit()
        }

        let cancelButton = Button("_Cancel")
        cancelButton.colorScheme = theme.actionButton
        cancelButton.x = Pos.right(of: saveButton) + 2
        cancelButton.y = Pos.top(of: saveButton)
        cancelButton.clicked = { _ in
            self.cancelAndExit()
        }

        window.addSubviews([
            bannerHeader,
            intro,
            configDirLine,
            rewriteModeTitle,
            rewriteModeValueLabel,
            rewriteModeButton,
            modelTitle,
            modelValueLabel,
            modelButton,
            hotkeyTitle,
            hotkeyValueLabel,
            hotkeyButton,
            microphoneTitle,
            microphoneValueLabel,
            microphoneButton,
            pauseMediaTitle,
            pauseMediaValueLabel,
            pauseMediaButton,
            smartRewriteThresholdTitle,
            smartRewriteThresholdValueLabel,
            smartRewriteThresholdButton,
            apiKeyTitle,
            apiKeySourceLabel,
            apiKeyField,
            testAPIKeyButton,
            clearAPIKeyCheckbox,
            saveButton,
            cancelButton,
        ])

        refreshLabels()

        Application.top.addSubview(window)
        Application.run()
        fatalError("unreachable")
    }

    private func testAPIKey() {
        let typedToken = apiKeyField.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !typedToken.isEmpty else {
            MessageBox.error("API Key Empty", message: "Please enter an API key to test.", buttons: ["Ok"])
            return
        }

        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(typedToken)", forHTTPHeaderField: "Authorization")

        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    MessageBox.error("Network Error", message: "Failed to connect: \(error.localizedDescription)", buttons: ["Ok"])
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        MessageBox.info("Success", message: "API Key is valid.")
                    } else if httpResponse.statusCode == 401 {
                        MessageBox.error("Authentication Error", message: "API Key is invalid (401 Unauthorized). Please check your key and try again.", buttons: ["Ok"])
                    } else {
                        MessageBox.error("Error", message: "Received HTTP status \(httpResponse.statusCode).", buttons: ["Ok"])
                    }
                } else {
                    MessageBox.error("Error", message: "Did not receive a valid HTTP response.", buttons: ["Ok"])
                }
            }
        }
        task.resume()
    }

    private func chooseRewriteMode() {
        let options = ["literal", "smart"]
        let currentIndex = rewriteMode == "literal" ? 0 : 1

        presentSelectionDialog(
            title: "Rewrite Mode",
            options: options,
            selectedIndex: currentIndex
        ) { index in
            self.rewriteMode = options[index]
            self.refreshLabels()
            return nil
        }
    }

    private func chooseModel() {
        let options = CLIConfigOptionCatalog.modelChoices(current: selectedModel)
        let currentIndex = options.firstIndex(of: selectedModel) ?? 0

        presentSelectionDialog(
            title: "OpenRouter Model",
            options: options,
            selectedIndex: currentIndex
        ) { index in
            let selected = options[index]
            if selected == CLIConfigOptionCatalog.customEntryLabel {
                return { self.promptCustomModel() }
            }
            self.selectedModel = selected
            self.refreshLabels()
            return nil
        }
    }

    private func promptCustomModel() {
        presentTextEntryDialog(
            title: "Custom OpenRouter Model",
            message: "Enter a model ID.",
            initialValue: selectedModel,
            secret: false
        ) { value in
            self.selectedModel = value
            self.refreshLabels()
        }
    }

    private func chooseHotkey() {
        let currentHotkey = resolvedHotkeyValue()
        let options = CLIConfigOptionCatalog.hotkeyChoices(
            current: currentHotkey,
            defaultShortcut: store.defaultShortcut
        )

        presentSelectionDialog(
            title: "Primary Hotkey",
            options: options,
            selectedIndex: 0
        ) { index in
            let selected = options[index]

            if selected == CLIConfigOptionCatalog.customEntryLabel {
                return { self.promptCustomHotkey() }
            }
            if selected.hasPrefix("Keep current (") {
                self.shortcutSelection = .keep
                self.refreshLabels()
                return nil
            }
            if selected.hasPrefix("Reset to default (") {
                self.shortcutSelection = .reset
                self.refreshLabels()
                return nil
            }

            self.shortcutSelection = .set(selected)
            self.refreshLabels()
            return nil
        }
    }

    private func promptCustomHotkey() {
        presentTextEntryDialog(
            title: "Custom Hotkey",
            message: "Example: ctrl+option+space",
            initialValue: resolvedHotkeyValue(),
            secret: false
        ) { value in
            self.shortcutSelection = .set(value)
            self.refreshLabels()
        }
    }

    private func choosePauseMediaMode() {
        let options = ["Enabled", "Disabled"]
        let currentIndex = pauseMediaWhileRecording ? 0 : 1

        presentSelectionDialog(
            title: "Pause Media While Recording",
            options: options,
            selectedIndex: currentIndex
        ) { index in
            self.pauseMediaWhileRecording = index == 0
            self.refreshLabels()
            return nil
        }
    }

    private func chooseSmartRewriteThreshold() {
        let options = CLIConfigOptionCatalog.smartRewriteThresholdChoices(current: smartRewriteThreshold)
        let currentIndex = options.firstIndex(of: "Current (\(smartRewriteThreshold))") ?? 0

        presentSelectionDialog(
            title: "Smart Rewrite Threshold",
            options: options,
            selectedIndex: currentIndex
        ) { index in
            let selected = options[index]
            if selected == CLIConfigOptionCatalog.customEntryLabel {
                return { self.promptCustomSmartRewriteThreshold() }
            }
            if selected.hasPrefix("Current (") {
                self.refreshLabels()
                return nil
            }

            let valueString = selected.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let value = Int(valueString) {
                self.smartRewriteThreshold = value
            }

            self.refreshLabels()
            return nil
        }
    }

    private func promptCustomSmartRewriteThreshold() {
        presentTextEntryDialog(
            title: "Custom Smart Rewrite Threshold",
            message: "Enter an integer value.",
            initialValue: String(smartRewriteThreshold),
            secret: false
        ) { value in
            if let intValue = Int(value) {
                self.smartRewriteThreshold = intValue
            }
            self.refreshLabels()
        }
    }

    private func chooseMicrophone() {
        let availableDevices = (try? AudioCapture.availableInputDevices()) ?? []
        var options: [String] = [
            "Keep current (\(resolvedMicrophoneValue()))",
            "Reset to system default"
        ]
        var optionSelections: [TermKitMicrophoneSelection] = [
            .keep,
            .reset
        ]

        for device in availableDevices {
            let defaultSuffix = device.isDefault ? " (default)" : ""
            options.append("\(device.name)\(defaultSuffix) [\(device.id)]")
            optionSelections.append(.set(device.id))
        }

        presentSelectionDialog(
            title: "Microphone Input",
            options: options,
            selectedIndex: 0
        ) { index in
            self.microphoneSelection = optionSelections[index]
            self.refreshLabels()
            return nil
        }
    }

    private func resolvedHotkeyValue() -> String {
        switch shortcutSelection {
        case .keep:
            return initialState.currentShortcut
        case .set(let value):
            return value
        case .reset:
            return store.defaultShortcut
        }
    }

    private func resolvedMicrophoneRawValue() -> String? {
        switch microphoneSelection {
        case .keep:
            return initialState.currentMicrophone
        case .set(let value):
            return value
        case .reset:
            return nil
        }
    }

    private func resolvedMicrophoneValue() -> String {
        resolvedMicrophoneRawValue() ?? "system default"
    }

    private func refreshLabels() {
        rewriteModeValueLabel.text = rewriteMode
        if rewriteMode == "smart" {
            modelValueLabel.text = selectedModel
            smartRewriteThresholdValueLabel.text = String(smartRewriteThreshold)
        } else {
            modelValueLabel.text = "(unused in literal mode) \(selectedModel)"
            smartRewriteThresholdValueLabel.text = "(unused in literal mode) \(smartRewriteThreshold)"
        }

        switch shortcutSelection {
        case .keep:
            hotkeyValueLabel.text = initialState.currentShortcut
        case .set(let value):
            hotkeyValueLabel.text = value
        case .reset:
            hotkeyValueLabel.text = "default (\(store.defaultShortcut))"
        }

        microphoneValueLabel.text = resolvedMicrophoneValue()
        pauseMediaValueLabel.text = pauseMediaWhileRecording ? "enabled" : "disabled"
        apiKeySourceLabel.text = "Current key source: \(initialState.apiKeySource)"
    }

    private func saveAndExit() {
        let apiKeyAction: TermKitAPIKeySelection
        let typedToken = apiKeyField.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !typedToken.isEmpty {
            apiKeyAction = .set(typedToken)
        } else if clearAPIKeyCheckbox.checked {
            apiKeyAction = .clear
        } else {
            apiKeyAction = .keep
        }

        if case .set(let shortcut) = shortcutSelection,
           HotkeyShortcut.parse(identifier: shortcut) == nil {
            MessageBox.error(
                "Invalid Hotkey",
                message: "Hotkey '\(shortcut)' is invalid. Use a format like ctrl+option+space.",
                buttons: ["Ok"]
            )
            return
        }

        do {
            try store.persist(
                shortcut: shortcutSelection,
                rewriteMode: rewriteMode,
                openRouterModel: rewriteMode == "smart" ? selectedModel : nil,
                pauseMediaWhileRecording: pauseMediaWhileRecording,
                microphone: microphoneSelection,
                smartRewriteThreshold: smartRewriteThreshold,
                apiKey: apiKeyAction
            )
            Application.shutdown(statusCode: 0)
        } catch {
            MessageBox.error(
                "Save Failed",
                message: "Could not save config: \(error.localizedDescription)",
                buttons: ["Ok"]
            )
        }
    }
    private func cancelAndExit() {
        fputs("config update cancelled\n", stderr)
        Application.shutdown(statusCode: 1)
    }

    private func presentSelectionDialog(
        title: String,
        options: [String],
        selectedIndex: Int,
        onSelect: @escaping (Int) -> (() -> Void)?
    ) {
        let dialogWidth = max(56, min(100, Application.terminalSize.width - 2))
        let dialogHeight = max(10, min(24, options.count + 7))

        let dialog = Dialog(title: title, width: dialogWidth, height: dialogHeight, buttons: [])
        dialog.colorScheme = theme.dialog

        let list = ListView(items: options)
        list.allowMarking = false
        list.colorScheme = theme.textInput
        list.selectedMarker = "> "
        list.selectedItem = max(0, min(selectedIndex, options.count - 1))
        list.x = Pos.at(1)
        list.y = Pos.at(1)
        list.width = Dim.fill(1)
        list.height = Dim.fill(3)
        list.activate = { index in
            let followUp = onSelect(index)
            Application.requestStop()
            if let followUp {
                // Let the current selector fully close before presenting a nested dialog.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: followUp)
            }
            return true
        }

        let selectButton = Button("_Select")
        selectButton.isDefault = true
        selectButton.colorScheme = theme.actionButton
        selectButton.clicked = { _ in
            let followUp = onSelect(list.selectedItem)
            Application.requestStop()
            if let followUp {
                // Let the current selector fully close before presenting a nested dialog.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: followUp)
            }
        }

        let cancelButton = Button("_Cancel")
        cancelButton.colorScheme = theme.actionButton
        cancelButton.clicked = { _ in
            Application.requestStop()
        }

        dialog.addSubview(list)
        dialog.addButton(selectButton)
        dialog.addButton(cancelButton)

        Application.present(top: dialog)
    }

    private func presentTextEntryDialog(
        title: String,
        message: String,
        initialValue: String,
        secret: Bool,
        onSelect: @escaping (String) -> Void
    ) {
        let dialog = Dialog(title: title, width: 80, height: 11, buttons: [])
        dialog.colorScheme = theme.dialog

        let promptLabel = Label(message)
        promptLabel.x = Pos.at(1)
        promptLabel.y = Pos.at(1)

        let field = TextField(initialValue)
        field.secret = secret
        field.colorScheme = theme.textInput
        field.x = Pos.at(1)
        field.y = Pos.at(3)
        field.width = Dim.fill(1)

        let applyButton = Button("_Apply")
        applyButton.isDefault = true
        applyButton.colorScheme = theme.actionButton
        applyButton.clicked = { _ in
            let value = field.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                return
            }
            onSelect(value)
            Application.requestStop()
        }

        let cancelButton = Button("_Cancel")
        cancelButton.colorScheme = theme.actionButton
        cancelButton.clicked = { _ in
            Application.requestStop()
        }

        dialog.addSubview(promptLabel)
        dialog.addSubview(field)
        dialog.addButton(applyButton)
        dialog.addButton(cancelButton)

        Application.present(top: dialog)
    }
}

enum TermKitConfigWizard {
    static func run(
        configDir: String,
        defaultShortcut: String,
        defaultRewriteMode: String,
        defaultOpenRouterModel: String,
        defaultPauseMediaWhileRecording: Bool,
        defaultSmartRewriteThreshold: Int
    ) -> Never {
        guard isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1 else {
            fputs("interactive config requires a TTY.\n", stderr)
            exit(2)
        }

        let store = TermKitConfigStore(
            configDir: configDir,
            defaultShortcut: defaultShortcut,
            defaultRewriteMode: defaultRewriteMode,
            defaultOpenRouterModel: defaultOpenRouterModel,
            defaultPauseMediaWhileRecording: defaultPauseMediaWhileRecording,
            defaultSmartRewriteThreshold: defaultSmartRewriteThreshold
        )

        TermKitConfigWizardApp(store: store).run()
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
