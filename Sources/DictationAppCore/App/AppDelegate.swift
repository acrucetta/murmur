#if canImport(AppKit)
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let menuBarController: MenuBarController
    private let onLaunch: (() -> Void)?
    private let onTerminate: (() -> Void)?

    public init(
        menuBarController: MenuBarController,
        onLaunch: (() -> Void)? = nil,
        onTerminate: (() -> Void)? = nil
    ) {
        self.menuBarController = menuBarController
        self.onLaunch = onLaunch
        self.onTerminate = onTerminate
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.installMenuBarItem()
        onLaunch?()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }
}
#endif
