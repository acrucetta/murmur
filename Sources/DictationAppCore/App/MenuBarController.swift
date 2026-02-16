#if canImport(AppKit)
import AppKit

@MainActor
public final class MenuBarController {
    private var statusItem: NSStatusItem?

    public init() {}

    public func installMenuBarItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        statusItem?.button?.title = "Murmur"
    }
}
#endif
