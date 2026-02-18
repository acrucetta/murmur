import Foundation

public struct OpenRouterTranscriptRewriterConfig: Equatable, Sendable {
    public let apiKey: String
    public let model: String
    public let endpoint: URL
    public let requestTimeoutSeconds: TimeInterval
    public let appNameHeader: String?
    public let refererHeader: String?

    public init(
        apiKey: String,
        model: String,
        endpoint: URL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
        requestTimeoutSeconds: TimeInterval = 20,
        appNameHeader: String? = "Murmur",
        refererHeader: String? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.appNameHeader = appNameHeader
        self.refererHeader = refererHeader
    }
}

public struct OpenRouterTransportResponse {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol OpenRouterTransporting {
    func send(request: URLRequest, timeout: TimeInterval) throws -> OpenRouterTransportResponse
}

public enum OpenRouterTransportError: Error {
    case timedOut
    case invalidResponse
}

public final class URLSessionOpenRouterTransport: OpenRouterTransporting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(request: URLRequest, timeout: TimeInterval) throws -> OpenRouterTransportResponse {
        let semaphore = DispatchSemaphore(value: 0)
        let result = TransportResult()

        let task = session.dataTask(with: request) { data, response, error in
            result.store(data: data, response: response, error: error)
            semaphore.signal()
        }
        task.resume()

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            task.cancel()
            throw OpenRouterTransportError.timedOut
        }

        let snapshot = result.snapshot()

        if let error = snapshot.error {
            throw error
        }

        guard let httpResponse = snapshot.response as? HTTPURLResponse else {
            throw OpenRouterTransportError.invalidResponse
        }

        return .init(statusCode: httpResponse.statusCode, body: snapshot.data ?? Data())
    }

    private final class TransportResult: @unchecked Sendable {
        private let lock = NSLock()
        private var data: Data?
        private var response: URLResponse?
        private var error: Error?

        func store(data: Data?, response: URLResponse?, error: Error?) {
            lock.lock()
            self.data = data
            self.response = response
            self.error = error
            lock.unlock()
        }

        func snapshot() -> (data: Data?, response: URLResponse?, error: Error?) {
            lock.lock()
            defer { lock.unlock() }
            return (data, response, error)
        }
    }
}

public final class OpenRouterTranscriptRewriter: TranscriptRewriting {
    public typealias DateProvider = () -> Date

    private static let contentStopWords: Set<String> = [
        "a", "an", "am", "and", "are", "as", "at", "be", "been", "but", "by", "can", "could", "did",
        "do", "does", "for", "had", "has", "have", "he", "her", "his", "i", "if", "in", "is", "it", "its",
        "me", "my", "of", "on", "or", "our", "she", "should", "that", "the", "their", "them", "there",
        "they", "this", "to", "was", "we", "were", "will", "with", "would", "you", "your",
    ]

    private let config: OpenRouterTranscriptRewriterConfig
    private let transport: OpenRouterTransporting
    private let logger: Logging
    private let now: DateProvider

    public init(
        config: OpenRouterTranscriptRewriterConfig,
        transport: OpenRouterTransporting = URLSessionOpenRouterTransport(),
        logger: Logging = NoopLogger(),
        now: @escaping DateProvider = Date.init
    ) {
        self.config = config
        self.transport = transport
        self.logger = logger
        self.now = now
    }

    public func rewrite(_ text: String, context: RewriteContext) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            logger.log("smart_rewrite_skipped reason=missing_api_key")
            return nil
        }

        let model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            logger.log("smart_rewrite_skipped reason=missing_model")
            return nil
        }

        guard config.requestTimeoutSeconds > 0 else {
            logger.log("smart_rewrite_skipped reason=invalid_request_timeout")
            return nil
        }

        guard let request = buildRequest(transcript: trimmed, context: context) else {
            logger.log("smart_rewrite_skipped reason=invalid_request")
            return nil
        }

        let startedAt = now()
        do {
            let response = try transport.send(request: request, timeout: config.requestTimeoutSeconds)
            let elapsedMs = max(0, Int((now().timeIntervalSince(startedAt) * 1000).rounded()))

            guard (200...299).contains(response.statusCode) else {
                logger.log("smart_rewrite_http_error status=\(response.statusCode)")
                return nil
            }

            guard let rewritten = parseTranscript(from: response.body) else {
                logger.log("smart_rewrite_parse_error")
                return nil
            }

            let cleanedRewrite = rewritten.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedRewrite.isEmpty else {
                logger.log("smart_rewrite_empty")
                return nil
            }
            if let rejectionReason = rewriteRejectionReason(candidate: cleanedRewrite, original: trimmed) {
                logger.log("smart_rewrite_rejected reason=\(rejectionReason)")
                return nil
            }

            logger.log("smart_rewrite_applied elapsed_ms=\(elapsedMs)")
            return cleanedRewrite
        } catch OpenRouterTransportError.timedOut {
            let timeoutMs = max(1, Int((config.requestTimeoutSeconds * 1000).rounded()))
            logger.log("smart_rewrite_transport_timeout timeout_ms=\(timeoutMs)")
            return nil
        } catch {
            logger.log("smart_rewrite_transport_error")
            return nil
        }
    }

    private func buildRequest(transcript: String, context: RewriteContext) -> URLRequest? {
        let appBundleID = context.frontmostAppBundleID ?? "unknown"
        let appName = context.frontmostAppName ?? "unknown"
        let userContent = [
            "mode=\(context.mode)",
            "frontmost_app_bundle_id=\(appBundleID)",
            "frontmost_app_name=\(appName)",
            "transcript=\(transcript)",
        ].joined(separator: "\n")

        let body: [String: Any] = [
            "model": config.model,
            "temperature": 0,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    Rewrite dictated text for clarity and correctness while preserving meaning. \
                    Fix punctuation, casing, obvious transcription mistakes, and accent-related homophone errors using context hints. \
                    Do not add explanations, refusals, policy text, or capability disclaimers. \
                    If input is unclear, return a minimally edited version of the original transcript. \
                    Return only the rewritten text with no explanation.
                    """,
                ],
                [
                    "role": "user",
                    "content": userContent,
                ],
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            return nil
        }

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.timeoutInterval = config.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        if let appNameHeader = config.appNameHeader?.trimmingCharacters(in: .whitespacesAndNewlines), !appNameHeader.isEmpty {
            request.setValue(appNameHeader, forHTTPHeaderField: "X-Title")
        }
        if let refererHeader = config.refererHeader?.trimmingCharacters(in: .whitespacesAndNewlines), !refererHeader.isEmpty {
            request.setValue(refererHeader, forHTTPHeaderField: "HTTP-Referer")
        }
        return request
    }

    private func parseTranscript(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any]
        else {
            return nil
        }

        if let stringContent = message["content"] as? String {
            return stringContent
        }

        if let contentArray = message["content"] as? [[String: Any]] {
            let textParts = contentArray.compactMap { $0["text"] as? String }
            let joined = textParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                return joined
            }
        }

        return nil
    }

    private func rewriteRejectionReason(candidate: String, original: String) -> String? {
        if hasUnboundedExpansion(candidate: candidate, original: original) {
            return "length_spike"
        }

        if hasLowContentOverlap(candidate: candidate, original: original) {
            return "low_content_overlap"
        }

        return nil
    }

    private func hasUnboundedExpansion(candidate: String, original: String) -> Bool {
        let originalTokens = canonicalTokens(from: original)
        let candidateTokens = canonicalTokens(from: candidate)
        guard !originalTokens.isEmpty, !candidateTokens.isEmpty else {
            return false
        }

        if original.count <= 80, candidate.count >= 180 {
            return true
        }

        let originalUnique = Set(originalTokens)
        let candidateUnique = Set(candidateTokens)
        guard !originalUnique.isEmpty else {
            return false
        }

        let overlapCount = originalUnique.intersection(candidateUnique).count
        let overlapRatio = Double(overlapCount) / Double(originalUnique.count)
        let lengthRatio = Double(candidateTokens.count) / Double(max(1, originalTokens.count))

        if originalUnique.count >= 3, overlapRatio < 0.34, lengthRatio >= 1.8 {
            return true
        }

        if overlapRatio < 0.2, candidate.count > 240 {
            return true
        }

        return false
    }

    private func hasLowContentOverlap(candidate: String, original: String) -> Bool {
        let originalContent = contentTokens(from: original)
        let candidateContent = contentTokens(from: candidate)
        guard originalContent.count >= 2, !candidateContent.isEmpty else {
            return false
        }

        let originalUnique = Set(originalContent)
        guard originalUnique.count >= 2 else {
            return false
        }
        let candidateUnique = Set(candidateContent)
        let overlapCount = originalUnique.intersection(candidateUnique).count
        let overlapRatio = Double(overlapCount) / Double(originalUnique.count)

        return overlapRatio < 0.25
    }

    private func contentTokens(from text: String) -> [String] {
        canonicalTokens(from: text).filter { !Self.contentStopWords.contains($0) }
    }

    private func canonicalTokens(from text: String) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                token.replacingOccurrences(
                    of: "^[^a-z0-9']+|[^a-z0-9']+$",
                    with: "",
                    options: .regularExpression
                )
            }
            .filter { !$0.isEmpty }
    }
}
