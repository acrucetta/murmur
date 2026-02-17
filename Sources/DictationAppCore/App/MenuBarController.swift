#if canImport(AppKit)
import AppKit

@MainActor
public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var stateItem: NSMenuItem?
    private var backendItem: NSMenuItem?
    private var errorItem: NSMenuItem?
    private var partialItem: NSMenuItem?

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
        scheduleDiagnosticsLog()
    }

    public func setState(_ state: SessionState) {
        stateItem?.title = "State: \(SessionStatePresentation.label(for: state))"

        switch state {
        case .listening:
            statusItem?.button?.contentTintColor = .systemRed
        case .error:
            statusItem?.button?.contentTintColor = .systemOrange
        default:
            statusItem?.button?.contentTintColor = nil
        }
    }

    public func setBackend(_ backend: String) {
        backendItem?.title = "Backend: \(backend)"
    }

    public func setLastErrorMessage(_ message: String?) {
        if let message, !message.isEmpty {
            errorItem?.title = "Last Error: \(message)"
        } else {
            errorItem?.title = "Last Error: none"
        }
    }

    public func setPartialTranscript(_ text: String?) {
        if let text, !text.isEmpty {
            partialItem?.title = "Partial: \(text)"
        } else {
            partialItem?.title = "Partial: -"
        }
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
            "metric menu_button_configured title=\(button.title) image_set=\(button.image != nil) length=\(statusItem?.length ?? -1)"
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

        let stateItem = NSMenuItem(title: "State: -", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        self.stateItem = stateItem

        let backendItem = NSMenuItem(title: "Backend: -", action: nil, keyEquivalent: "")
        backendItem.isEnabled = false
        menu.addItem(backendItem)
        self.backendItem = backendItem

        let errorItem = NSMenuItem(title: "Last Error: -", action: nil, keyEquivalent: "")
        errorItem.isEnabled = false
        menu.addItem(errorItem)
        self.errorItem = errorItem

        let partialItem = NSMenuItem(title: "Partial: -", action: nil, keyEquivalent: "")
        partialItem.isEnabled = false
        menu.addItem(partialItem)
        self.partialItem = partialItem

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Murmur", action: #selector(quitPressed(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
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
            Swift.print("metric menu_bar_diagnostics status_item=false")
            return
        }
        let hasButton = statusItem.button != nil
        let attached = statusItem.button?.window != nil
        let visible = statusItem.isVisible
        let hasImage = statusItem.button?.image != nil
        let frame = statusItem.button?.window?.frame ?? .zero
        let frameString = "\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.size.width)),\(Int(frame.size.height))"

        Swift.print(
            "metric menu_bar_diagnostics status_item=true button=\(hasButton) attached=\(attached) visible=\(visible) image=\(hasImage) frame=\(frameString)"
        )
    }

}
#endif
