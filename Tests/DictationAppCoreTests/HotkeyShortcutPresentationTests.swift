import Foundation
import Testing
@testable import DictationAppCore

struct HotkeyShortcutPresentationTests {
    @Test
    func formatsReadableLabelForSpaceShortcut() {
        let shortcut = HotkeyShortcut.parse(identifier: "ctrl+shift+space")
        #expect(shortcut != nil)
        #expect(HotkeyShortcutPresentation.label(for: shortcut!) == "ctrl + shift + space")
    }

    @Test
    func formatsLetterKeyShortcutWithUppercaseKey() {
        let shortcut = HotkeyShortcut.parse(identifier: "ctrl+option+d")
        #expect(shortcut != nil)
        #expect(HotkeyShortcutPresentation.label(for: shortcut!) == "ctrl + option + D")
    }

    @Test
    func buildsOverlayPromptText() {
        let shortcut = HotkeyShortcut.parse(identifier: "ctrl+shift+space")
        #expect(shortcut != nil)
        #expect(
            HotkeyShortcutPresentation.overlayPrompt(for: shortcut!) == "Hold ctrl + shift + space to start dictating"
        )
    }

    @Test
    func buildsToggleModeOverlayPromptText() {
        let shortcut = HotkeyShortcut.parse(identifier: "ctrl+shift+space")
        #expect(shortcut != nil)
        #expect(
            HotkeyShortcutPresentation.overlayPrompt(for: shortcut!, toggleMode: true) == "Press ctrl + shift + space to start dictating"
        )
    }
}
