import Testing
@testable import DictationAppCore

struct InsertionFallbackTests {
    @Test
    func usesAccessibilityPathWhenPrimarySucceeds() {
        let direct = DirectInserterSpy(
            nextResult: .init(success: true, method: .accessibilityDirect, error: nil)
        )
        let fallback = ClipboardInserterSpy(
            nextResult: .init(success: true, method: .clipboardPaste, error: nil)
        )
        let writer = FocusedFieldWriter(
            directInserter: direct,
            clipboardFallbackInserter: fallback
        )

        let result = writer.insert("hello")

        #expect(result.success == true)
        #expect(result.method == .accessibilityDirect)
        #expect(direct.callCount == 1)
        #expect(fallback.callCount == 0)
    }

    @Test
    func usesClipboardFallbackWhenAccessibilityFails() {
        let direct = DirectInserterSpy(
            nextResult: .init(success: false, method: .accessibilityDirect, error: .noFocusedField)
        )
        let fallback = ClipboardInserterSpy(
            nextResult: .init(success: true, method: .clipboardPaste, error: nil)
        )
        let writer = FocusedFieldWriter(
            directInserter: direct,
            clipboardFallbackInserter: fallback
        )

        let result = writer.insert("hello")

        #expect(result.success == true)
        #expect(result.method == .clipboardPaste)
        #expect(direct.callCount == 1)
        #expect(fallback.callCount == 1)
    }

    @Test
    func returnsFallbackFailureWhenBothPathsFail() {
        let direct = DirectInserterSpy(
            nextResult: .init(success: false, method: .accessibilityDirect, error: .insertionFailed)
        )
        let fallback = ClipboardInserterSpy(
            nextResult: .init(success: false, method: .clipboardPaste, error: .secureInputBlocked)
        )
        let writer = FocusedFieldWriter(
            directInserter: direct,
            clipboardFallbackInserter: fallback
        )

        let result = writer.insert("hello")

        #expect(result.success == false)
        #expect(result.method == .clipboardPaste)
        #expect(result.error == .secureInputBlocked)
        #expect(fallback.callCount == 1)
    }

    @Test
    func doesNotFallbackForEngineError() {
        let direct = DirectInserterSpy(
            nextResult: .init(success: false, method: .accessibilityDirect, error: .engineError)
        )
        let fallback = ClipboardInserterSpy(
            nextResult: .init(success: true, method: .clipboardPaste, error: nil)
        )
        let writer = FocusedFieldWriter(
            directInserter: direct,
            clipboardFallbackInserter: fallback
        )

        let result = writer.insert("hello")

        #expect(result.success == false)
        #expect(result.error == .engineError)
        #expect(fallback.callCount == 0)
    }
}

private final class DirectInserterSpy: AccessibilityDirectInserting {
    var callCount = 0
    let nextResult: InsertResult

    init(nextResult: InsertResult) {
        self.nextResult = nextResult
    }

    func insertDirect(_ text: String) -> InsertResult {
        callCount += 1
        return nextResult
    }
}

private final class ClipboardInserterSpy: ClipboardFallbackPasting {
    var callCount = 0
    let nextResult: InsertResult

    init(nextResult: InsertResult) {
        self.nextResult = nextResult
    }

    func paste(_ text: String) -> InsertResult {
        callCount += 1
        return nextResult
    }
}
