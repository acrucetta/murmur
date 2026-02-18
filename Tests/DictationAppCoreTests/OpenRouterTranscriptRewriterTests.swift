import Foundation
import Testing
@testable import DictationAppCore

struct OpenRouterTranscriptRewriterTests {
    @Test
    func sendsContextualRequestAndReturnsFirstChoiceContent() throws {
        let transport = OpenRouterTransportSpy()
        transport.nextResponse = .init(
            statusCode: 200,
            body: Data(
                """
                {"choices":[{"message":{"content":"Ship this on Friday."}}]}
                """.utf8
            )
        )

        let rewriter = OpenRouterTranscriptRewriter(
            config: .init(
                apiKey: "test-token",
                model: "mistralai/mistral-small-3.1-24b-instruct",
                requestTimeoutSeconds: 12
            ),
            transport: transport,
            logger: NoopLogger()
        )

        let result = rewriter.rewrite(
            "Ship this tomorrow.",
            context: .init(
                frontmostAppBundleID: "com.apple.mail",
                frontmostAppName: "Mail",
                mode: "smart"
            )
        )

        #expect(result == "Ship this on Friday.")
        #expect(transport.callCount == 1)
        #expect(transport.lastTimeout == 12)
        #expect(transport.lastRequest?.url?.absoluteString == "https://openrouter.ai/api/v1/chat/completions")
        #expect(transport.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let requestData = try #require(transport.lastRequest?.httpBody)
        let payload = try JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        let model = payload?["model"] as? String
        #expect(model == "mistralai/mistral-small-3.1-24b-instruct")
        let messages = payload?["messages"] as? [[String: Any]]
        let userContent = messages?.first(where: { ($0["role"] as? String) == "user" })?["content"] as? String
        #expect(userContent?.contains("frontmost_app_bundle_id=com.apple.mail") == true)
        #expect(userContent?.contains("transcript=Ship this tomorrow.") == true)
    }

    @Test
    func returnsNilWhenTransportTimesOut() {
        let transport = OpenRouterTransportSpy()
        transport.nextError = OpenRouterTransportError.timedOut

        let rewriter = OpenRouterTranscriptRewriter(
            config: .init(
                apiKey: "test-token",
                model: "mistralai/mistral-small-3.1-24b-instruct"
            ),
            transport: transport,
            logger: NoopLogger()
        )

        let result = rewriter.rewrite(
            "Original sentence.",
            context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "smart")
        )

        #expect(result == nil)
        #expect(transport.callCount == 1)
    }

    @Test
    func returnsNilWhenApiKeyMissing() {
        let transport = OpenRouterTransportSpy()
        let rewriter = OpenRouterTranscriptRewriter(
            config: .init(
                apiKey: "",
                model: "mistralai/mistral-small-3.1-24b-instruct"
            ),
            transport: transport,
            logger: NoopLogger()
        )

        let result = rewriter.rewrite(
            "Original sentence.",
            context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "smart")
        )

        #expect(result == nil)
        #expect(transport.callCount == 0)
    }

    @Test
    func returnsNilWhenModelReturnsRefusalText() {
        let transport = OpenRouterTransportSpy()
        transport.nextResponse = .init(
            statusCode: 200,
            body: Data(
                """
                {"choices":[{"message":{"content":"I'm sorry, but I can't assist with that request."}}]}
                """.utf8
            )
        )
        let rewriter = OpenRouterTranscriptRewriter(
            config: .init(
                apiKey: "test-token",
                model: "mistralai/mistral-small-3.1-24b-instruct"
            ),
            transport: transport,
            logger: NoopLogger()
        )

        let result = rewriter.rewrite(
            "Are you joining the call?",
            context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "smart")
        )

        #expect(result == nil)
    }

    @Test
    func returnsNilWhenRewriteIsOffTopicAndMuchLonger() {
        let transport = OpenRouterTransportSpy()
        transport.nextResponse = .init(
            statusCode: 200,
            body: Data(
                """
                {"choices":[{"message":{"content":"I do not have access to the requested tool output, but I can provide a high-level explanation of what likely happened and suggest several alternative approaches for diagnosing the issue in detail."}}]}
                """.utf8
            )
        )
        let rewriter = OpenRouterTranscriptRewriter(
            config: .init(
                apiKey: "test-token",
                model: "mistralai/mistral-small-3.1-24b-instruct"
            ),
            transport: transport,
            logger: NoopLogger()
        )

        let result = rewriter.rewrite(
            "Ship this tomorrow.",
            context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "smart")
        )

        #expect(result == nil)
    }

    @Test
    func returnsNilWhenRewriteHasNoContentOverlap() {
        let transport = OpenRouterTransportSpy()
        transport.nextResponse = .init(
            statusCode: 200,
            body: Data(
                """
                {"choices":[{"message":{"content":"Blue elephants dance nightly under distant stars."}}]}
                """.utf8
            )
        )
        let rewriter = OpenRouterTranscriptRewriter(
            config: .init(
                apiKey: "test-token",
                model: "mistralai/mistral-small-3.1-24b-instruct"
            ),
            transport: transport,
            logger: NoopLogger()
        )

        let result = rewriter.rewrite(
            "Are you joining the call?",
            context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "smart")
        )

        #expect(result == nil)
    }
}

private final class OpenRouterTransportSpy: OpenRouterTransporting {
    var callCount = 0
    var lastRequest: URLRequest?
    var lastTimeout: TimeInterval?
    var simulatedDelay: TimeInterval = 0
    var nextResponse: OpenRouterTransportResponse = .init(statusCode: 500, body: Data())
    var nextError: Error?

    func send(request: URLRequest, timeout: TimeInterval) throws -> OpenRouterTransportResponse {
        callCount += 1
        lastRequest = request
        lastTimeout = timeout

        if simulatedDelay > 0 {
            Thread.sleep(forTimeInterval: simulatedDelay)
        }

        if let nextError {
            throw nextError
        }

        return nextResponse
    }
}
