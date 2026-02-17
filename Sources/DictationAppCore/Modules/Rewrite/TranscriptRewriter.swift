import Foundation

public enum TranscriptRewriteMode: String, Equatable, Sendable {
    case literal
    case smart

    public static func parse(_ rawValue: String) -> TranscriptRewriteMode? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return TranscriptRewriteMode(rawValue: normalized)
    }
}

public struct RewriteContext: Equatable, Sendable {
    public let frontmostAppBundleID: String?
    public let frontmostAppName: String?
    public let mode: String

    public init(frontmostAppBundleID: String?, frontmostAppName: String?, mode: String) {
        self.frontmostAppBundleID = frontmostAppBundleID
        self.frontmostAppName = frontmostAppName
        self.mode = mode
    }
}

public protocol RewriteContextProviding {
    func currentContext() -> RewriteContext
}

public struct StaticRewriteContextProvider: RewriteContextProviding {
    private let context: RewriteContext

    public init(context: RewriteContext) {
        self.context = context
    }

    public func currentContext() -> RewriteContext {
        context
    }
}

public protocol TranscriptRewriting {
    func rewrite(_ text: String, context: RewriteContext) -> String?
}

public struct NoopTranscriptRewriter: TranscriptRewriting {
    public init() {}

    public func rewrite(_ text: String, context: RewriteContext) -> String? {
        nil
    }
}
