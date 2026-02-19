#if canImport(AppKit)
import AppKit

public struct MenuBarSettingsSnapshot {
    public let shortcutIdentifier: String
    public let rewriteMode: TranscriptRewriteMode
    public let openRouterModel: String
    public let pauseMediaWhileRecording: Bool
    public let preferredMicrophone: String?
    public let availableMicrophones: [AudioInputDevice]

    public init(
        shortcutIdentifier: String,
        rewriteMode: TranscriptRewriteMode,
        openRouterModel: String,
        pauseMediaWhileRecording: Bool,
        preferredMicrophone: String?,
        availableMicrophones: [AudioInputDevice]
    ) {
        self.shortcutIdentifier = shortcutIdentifier
        self.rewriteMode = rewriteMode
        self.openRouterModel = openRouterModel
        self.pauseMediaWhileRecording = pauseMediaWhileRecording
        self.preferredMicrophone = preferredMicrophone
        self.availableMicrophones = availableMicrophones
    }
}

public enum MenuBarSettingsAction {
    case setRewriteMode(TranscriptRewriteMode)
    case setOpenRouterModel(String)
    case setPauseMediaWhileRecording(Bool)
    case setPreferredMicrophone(String?)
}

@MainActor
public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var shortcutItem: NSMenuItem?
    private var rewriteModeItem: NSMenuItem?
    private var modelItem: NSMenuItem?
    private var pauseMediaItem: NSMenuItem?
    private var microphoneItem: NSMenuItem?
    private var settingsSnapshot: MenuBarSettingsSnapshot?

    public var onSettingsAction: ((MenuBarSettingsAction) -> Void)?

    public override init() {
        super.init()
    }

    public func installMenuBarItem() {
        if statusItem == nil {
            // Compact icon-only badge uses minimal menu bar width.
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }
        statusItem?.isVisible = true
        configureButton()
        configureMenuIfNeeded()
        setState(.idle)
        setBackend("initializing")
        setLastErrorMessage(nil)
        setPartialTranscript(nil)
        refreshSettingsMenu()
        scheduleDiagnosticsLog()
    }

    public func setState(_ state: SessionState) {
        _ = state
    }

    public func setBackend(_ backend: String) {
        _ = backend
    }

    public func setLastErrorMessage(_ message: String?) {
        _ = message
    }

    public func setPartialTranscript(_ text: String?) {
        _ = text
    }

    public func setSettings(_ snapshot: MenuBarSettingsSnapshot) {
        settingsSnapshot = snapshot
        refreshSettingsMenu()
    }

    private func configureButton() {
        guard let button = statusItem?.button else {
            return
        }

        button.image = makeStatusIcon()
        button.imagePosition = .imageOnly
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = "Murmur Dictation"
        statusItem?.length = NSStatusItem.squareLength
        Swift.print(
            RuntimeLogFormatter.format(
                "metric menu_button_configured title=\(button.title) image_set=\(button.image != nil) length=\(statusItem?.length ?? -1)"
            )
        )
    }

    private func makeStatusIcon() -> NSImage? {
        let symbolName = "waveform.circle.fill"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Murmur") {
            image.isTemplate = true
            return image
        }
        return NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Murmur")
    }

    private func configureMenuIfNeeded() {
        if menu == nil {
            menu = NSMenu()
        }

        guard let menu else {
            return
        }
        if !menu.items.isEmpty {
            return
        }

        let shortcutItem = NSMenuItem(title: "Shortcut: -", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)
        self.shortcutItem = shortcutItem

        let rewriteModeItem = NSMenuItem(title: "Rewrite Mode: -", action: nil, keyEquivalent: "")
        menu.addItem(rewriteModeItem)
        self.rewriteModeItem = rewriteModeItem

        let modelItem = NSMenuItem(title: "Smart Model: -", action: nil, keyEquivalent: "")
        menu.addItem(modelItem)
        self.modelItem = modelItem

        let pauseMediaItem = NSMenuItem(
            title: "Pause Media While Recording",
            action: #selector(togglePauseMedia(_:)),
            keyEquivalent: ""
        )
        pauseMediaItem.target = self
        menu.addItem(pauseMediaItem)
        self.pauseMediaItem = pauseMediaItem

        let microphoneItem = NSMenuItem(title: "Microphone: -", action: nil, keyEquivalent: "")
        menu.addItem(microphoneItem)
        self.microphoneItem = microphoneItem

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Murmur", action: #selector(quitPressed(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func refreshSettingsMenu() {
        guard let snapshot = settingsSnapshot else {
            shortcutItem?.title = "Shortcut: -"
            rewriteModeItem?.title = "Rewrite Mode: -"
            modelItem?.title = "Smart Model: -"
            pauseMediaItem?.state = .off
            pauseMediaItem?.isEnabled = false
            microphoneItem?.title = "Microphone: -"
            return
        }

        shortcutItem?.title = "Shortcut: \(snapshot.shortcutIdentifier)"
        rewriteModeItem?.title = "Rewrite Mode: \(snapshot.rewriteMode.rawValue)"
        rewriteModeItem?.submenu = makeRewriteModeSubmenu(snapshot: snapshot)
        modelItem?.title = "Smart Model: \(snapshot.openRouterModel)"
        modelItem?.submenu = makeModelSubmenu(snapshot: snapshot)
        pauseMediaItem?.state = snapshot.pauseMediaWhileRecording ? .on : .off
        pauseMediaItem?.isEnabled = true
        microphoneItem?.title = "Microphone: \(displayMicrophoneLabel(for: snapshot))"
        microphoneItem?.submenu = makeMicrophoneSubmenu(snapshot: snapshot)
    }

    private func makeRewriteModeSubmenu(snapshot: MenuBarSettingsSnapshot) -> NSMenu {
        let submenu = NSMenu(title: "Rewrite Mode")

        let literalItem = NSMenuItem(title: "Literal", action: #selector(selectRewriteMode(_:)), keyEquivalent: "")
        literalItem.target = self
        literalItem.tag = 0
        literalItem.state = snapshot.rewriteMode == .literal ? .on : .off
        submenu.addItem(literalItem)

        let smartItem = NSMenuItem(title: "Smart", action: #selector(selectRewriteMode(_:)), keyEquivalent: "")
        smartItem.target = self
        smartItem.tag = 1
        smartItem.state = snapshot.rewriteMode == .smart ? .on : .off
        submenu.addItem(smartItem)

        return submenu
    }

    private func makeModelSubmenu(snapshot: MenuBarSettingsSnapshot) -> NSMenu {
        let submenu = NSMenu(title: "Smart Model")
        let choices = CLIConfigOptionCatalog.modelChoices(current: snapshot.openRouterModel)

        for choice in choices where choice != CLIConfigOptionCatalog.customEntryLabel {
            let item = NSMenuItem(title: choice, action: #selector(selectOpenRouterModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice
            item.state = choice == snapshot.openRouterModel ? .on : .off
            submenu.addItem(item)
        }

        return submenu
    }

    private func makeMicrophoneSubmenu(snapshot: MenuBarSettingsSnapshot) -> NSMenu {
        let submenu = NSMenu(title: "Microphone")
        let preferred = snapshot.preferredMicrophone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSystemDefaultSelected = preferred == nil || preferred?.isEmpty == true
        let autoDetectTitle = autoDetectMicrophoneTitle(from: snapshot.availableMicrophones)

        let defaultItem = NSMenuItem(
            title: autoDetectTitle,
            action: #selector(selectMicrophone(_:)),
            keyEquivalent: ""
        )
        defaultItem.target = self
        defaultItem.representedObject = ""
        defaultItem.state = isSystemDefaultSelected ? .on : .off
        submenu.addItem(defaultItem)

        var matchedPreferred = isSystemDefaultSelected
        if snapshot.availableMicrophones.isEmpty {
            let emptyItem = NSMenuItem(title: "No microphones discovered", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            submenu.addItem(NSMenuItem.separator())
            for device in snapshot.availableMicrophones {
                let suffix = device.isDefault ? " (default)" : ""
                let item = NSMenuItem(
                    title: "\(device.name)\(suffix)",
                    action: #selector(selectMicrophone(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = device.id

                let isSelected =
                    preferred == device.id ||
                    preferred?.compare(device.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                if isSelected {
                    matchedPreferred = true
                }
                item.state = isSelected ? .on : .off
                submenu.addItem(item)
            }
        }

        if !matchedPreferred, let preferred, !preferred.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let unavailable = NSMenuItem(title: "Current (unavailable): \(preferred)", action: nil, keyEquivalent: "")
            unavailable.isEnabled = false
            unavailable.state = .on
            submenu.addItem(unavailable)
        }

        return submenu
    }

    private func displayMicrophoneLabel(for snapshot: MenuBarSettingsSnapshot) -> String {
        guard let preferred = snapshot.preferredMicrophone?.trimmingCharacters(in: .whitespacesAndNewlines),
              !preferred.isEmpty
        else {
            return autoDetectMicrophoneTitle(from: snapshot.availableMicrophones)
        }

        if let matched = snapshot.availableMicrophones.first(where: {
            $0.id == preferred ||
                $0.name.compare(preferred, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return matched.name
        }

        return preferred
    }

    private func autoDetectMicrophoneTitle(from devices: [AudioInputDevice]) -> String {
        if let defaultDevice = devices.first(where: { $0.isDefault }) {
            return "Auto-detect (\(defaultDevice.name))"
        }
        return "Auto-detect"
    }

    @objc private func selectRewriteMode(_ sender: NSMenuItem) {
        let mode: TranscriptRewriteMode = sender.tag == 1 ? .smart : .literal
        onSettingsAction?(.setRewriteMode(mode))
    }

    @objc private func selectOpenRouterModel(_ sender: NSMenuItem) {
        guard let model = sender.representedObject as? String else {
            return
        }
        onSettingsAction?(.setOpenRouterModel(model))
    }

    @objc private func togglePauseMedia(_ sender: NSMenuItem) {
        let current = settingsSnapshot?.pauseMediaWhileRecording ?? false
        onSettingsAction?(.setPauseMediaWhileRecording(!current))
    }

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        let selected = (sender.representedObject as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selected, !selected.isEmpty {
            onSettingsAction?(.setPreferredMicrophone(selected))
        } else {
            onSettingsAction?(.setPreferredMicrophone(nil))
        }
    }

    @objc private func quitPressed(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private func scheduleDiagnosticsLog() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            logDiagnostics()
        }
    }

    private func logDiagnostics() {
        guard let statusItem else {
            Swift.print(RuntimeLogFormatter.format("metric menu_bar_diagnostics status_item=false"))
            return
        }
        let hasButton = statusItem.button != nil
        let attached = statusItem.button?.window != nil
        let visible = statusItem.isVisible
        let hasImage = statusItem.button?.image != nil
        let frame = statusItem.button?.window?.frame ?? .zero
        let frameString = "\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.size.width)),\(Int(frame.size.height))"

        Swift.print(
            RuntimeLogFormatter.format(
                "metric menu_bar_diagnostics status_item=true button=\(hasButton) attached=\(attached) visible=\(visible) image=\(hasImage) frame=\(frameString)"
            )
        )
    }

}
#endif
