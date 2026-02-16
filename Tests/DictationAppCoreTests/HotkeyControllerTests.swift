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
}
