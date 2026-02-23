import AppKit
import Testing
@testable import DictationAppCore

struct ClipboardFallbackInserterTests {
    @Test
    func successfulPasteLeavesInsertedTextInClipboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("murmur-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        _ = pasteboard.setString("original clipboard value", forType: .string)

        let inserter = ClipboardFallbackInserter(
            pasteboard: pasteboard,
            eventPoster: EventPosterStub(shouldSucceed: true),
            sleeper: { _ in }
        )

        let result = inserter.paste("dictated text")

        #expect(result.success == true)
        #expect(result.method == .clipboardPaste)
        #expect(pasteboard.string(forType: .string) == "dictated text")
    }
}

private struct EventPosterStub: CGEventPosting {
    let shouldSucceed: Bool

    func postCommandV() -> Bool {
        shouldSucceed
    }
}
