import AppKit
import XCTest
@testable import DictationAppCore

final class ClipboardFallbackInserterTests: XCTestCase {
    func testSuccessfulPasteLeavesInsertedTextInClipboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("murmur-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        _ = pasteboard.setString("original clipboard value", forType: .string)

        let inserter = ClipboardFallbackInserter(
            pasteboard: pasteboard,
            eventPoster: EventPosterStub(shouldSucceed: true),
            sleeper: { _ in }
        )

        let result = inserter.paste("dictated text")

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.method, .clipboardPaste)
        XCTAssertEqual(pasteboard.string(forType: .string), "dictated text")
    }
}

private struct EventPosterStub: CGEventPosting {
    let shouldSucceed: Bool

    func postCommandV() -> Bool {
        shouldSucceed
    }
}
