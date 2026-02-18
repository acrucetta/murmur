import Testing
@testable import DictationAppCore

struct InsertionSurfacePolicyTests {
    @Test
    func notesRequiresClipboardFallback() {
        #expect(InsertionSurfacePolicy.requiresClipboardFallback(bundleIdentifier: "com.apple.Notes"))
    }

    @Test
    func terminalAppBundleIDsRequireClipboardFallback() {
        #expect(InsertionSurfacePolicy.requiresClipboardFallback(bundleIdentifier: "com.apple.Terminal"))
        #expect(InsertionSurfacePolicy.requiresClipboardFallback(bundleIdentifier: "com.googlecode.iterm2"))
        #expect(InsertionSurfacePolicy.requiresClipboardFallback(bundleIdentifier: "com.github.wez.wezterm"))
    }

    @Test
    func regularEditorDoesNotRequireClipboardFallback() {
        #expect(!InsertionSurfacePolicy.requiresClipboardFallback(bundleIdentifier: "com.microsoft.VSCode"))
    }
}
