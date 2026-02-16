#if canImport(AppKit)
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let menuBarController: MenuBarController

    public init(menuBarController: MenuBarController) {
        self.menuBarController = menuBarController
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.installMenuBarItem()
    }
}
#endif
