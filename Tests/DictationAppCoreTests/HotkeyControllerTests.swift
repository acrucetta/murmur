import Foundation
import Testing
@testable import DictationAppCore
#if canImport(Carbon)
import Carbon
#endif

struct HotkeyControllerTests {
    @Test
    func defaultPushToTalkShortcutUsesControlShiftSpace() {
#if canImport(Carbon)
        #expect(HotkeyShortcut.defaultPushToTalk.keyCode == UInt32(kVK_Space))
        #expect(HotkeyShortcut.defaultPushToTalk.modifiers == UInt32(controlKey | shiftKey))
        #expect(HotkeyShortcut.defaultBackupPushToTalk.keyCode == UInt32(kVK_ANSI_D))
        #expect(HotkeyShortcut.defaultBackupPushToTalk.modifiers == UInt32(controlKey | shiftKey))
#else
        #expect(HotkeyShortcut.defaultPushToTalk.keyCode == 49)
#endif
    }

    @Test
    func shortcutMatcherRequiresExactModifierSet() {
#if canImport(Carbon)
        let shortcut = HotkeyShortcut.defaultPushToTalk
        #expect(shortcut.matchesCGEvent(keyCode: UInt16(kVK_Space), flags: [.maskControl, .maskShift]))
        #expect(!shortcut.matchesCGEvent(keyCode: UInt16(kVK_Space), flags: [.maskControl]))
        #expect(!shortcut.matchesCGEvent(keyCode: UInt16(kVK_Space), flags: [.maskControl, .maskShift, .maskAlternate]))
        #expect(!shortcut.matchesCGEvent(keyCode: UInt16(kVK_ANSI_A), flags: [.maskControl, .maskShift]))
#endif
    }

    @Test
    func parsesShortcutIdentifierForSpaceCombo() {
#if canImport(Carbon)
        let parsed = HotkeyShortcut.parse(identifier: "ctrl+shift+space")
        #expect(parsed == .init(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | shiftKey)))
#endif
    }

    @Test
    func parsesShortcutIdentifierForLetterCombo() {
#if canImport(Carbon)
        let parsed = HotkeyShortcut.parse(identifier: "cmd+option+d")
        #expect(parsed == .init(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey | optionKey)))
#endif
    }

    @Test
    func rejectsShortcutIdentifierWithoutModifier() {
#if canImport(Carbon)
        #expect(HotkeyShortcut.parse(identifier: "space") == nil)
#endif
    }

    @Test
    func rejectsShortcutIdentifierWithUnknownKey() {
#if canImport(Carbon)
        #expect(HotkeyShortcut.parse(identifier: "ctrl+shift+f13") == nil)
#endif
    }
}
