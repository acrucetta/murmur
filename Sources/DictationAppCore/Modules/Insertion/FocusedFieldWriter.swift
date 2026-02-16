public protocol FocusedFieldWriting {
    func insert(_ text: String) -> InsertResult
}

public protocol AccessibilityDirectInserting {
    func insertDirect(_ text: String) -> InsertResult
}

public protocol ClipboardFallbackPasting {
    func paste(_ text: String) -> InsertResult
}

public final class FocusedFieldWriter: FocusedFieldWriting {
    private let directInserter: AccessibilityDirectInserting
    private let clipboardFallbackInserter: ClipboardFallbackPasting

    public init(
        directInserter: AccessibilityDirectInserting,
        clipboardFallbackInserter: ClipboardFallbackPasting
    ) {
        self.directInserter = directInserter
        self.clipboardFallbackInserter = clipboardFallbackInserter
    }

    public convenience init() {
        self.init(
            directInserter: AccessibilityDirectInserter(),
            clipboardFallbackInserter: ClipboardFallbackInserter()
        )
    }

    public convenience init(insertionClosure: @escaping (String) -> InsertResult) {
        self.init(
            directInserter: ClosureDirectInserter(closure: insertionClosure),
            clipboardFallbackInserter: DisabledClipboardInserter()
        )
    }

    public func insert(_ text: String) -> InsertResult {
        let primaryResult = directInserter.insertDirect(text)
        guard !primaryResult.success else {
            return primaryResult
        }

        guard shouldAttemptFallback(for: primaryResult.error) else {
            return primaryResult
        }

        return clipboardFallbackInserter.paste(text)
    }

    private func shouldAttemptFallback(for error: FailureCode?) -> Bool {
        guard let error else {
            return true
        }

        switch error {
        case .engineError:
            return false
        case .permissionDenied, .noFocusedField, .secureInputBlocked, .insertionFailed:
            return true
        }
    }
}

private struct ClosureDirectInserter: AccessibilityDirectInserting {
    let closure: (String) -> InsertResult

    func insertDirect(_ text: String) -> InsertResult {
        closure(text)
    }
}

private struct DisabledClipboardInserter: ClipboardFallbackPasting {
    func paste(_ text: String) -> InsertResult {
        .init(success: false, method: .clipboardPaste, error: .insertionFailed)
    }
}
