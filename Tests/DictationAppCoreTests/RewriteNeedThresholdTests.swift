@testable import DictationAppCore
import XCTest

final class RewriteNeedThresholdTests: XCTestCase {
    private var rewriter: OpenRouterTranscriptRewriter!
    private var config: OpenRouterTranscriptRewriterConfig!
    private var transport: MockTransport!
    private var logger: TestLogger!

    override func setUp() {
        super.setUp()
        transport = MockTransport()
        logger = TestLogger()
    }

    func testShouldNotRewriteWhenScoreIsBelowThreshold() {
        config = OpenRouterTranscriptRewriterConfig(apiKey: "test-key", model: "test-model", rewriteNeedThreshold: 5)
        rewriter = OpenRouterTranscriptRewriter(config: config, transport: transport, logger: logger)
        let result = rewriter.rewrite("this is a short test", context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "test"))
        XCTAssertNil(result)
        XCTAssertTrue(logger.messages.contains { $0.hasPrefix("smart_rewrite_skipped reason=low_need") })
    }

    func testShouldRewriteWhenScoreIsEqualToThreshold() {
        config = OpenRouterTranscriptRewriterConfig(apiKey: "test-key", model: "test-model", rewriteNeedThreshold: 1)
        rewriter = OpenRouterTranscriptRewriter(config: config, transport: transport, logger: logger)
        transport.response = .success(OpenRouterTransportResponse(statusCode: 200, body: """
        {
            "choices": [{
                "message": {
                    "content": "this is a long test that should be rewritten"
                }
            }]
        }
        """.data(using: .utf8)!))

        let result = rewriter.rewrite("this is a long test that should be rewritten", context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "test"))

        XCTAssertNotNil(result)
        XCTAssertTrue(logger.messages.contains { $0.hasPrefix("smart_rewrite_applied") })
    }

    func testShouldRewriteWhenScoreIsAboveThreshold() {
        config = OpenRouterTranscriptRewriterConfig(apiKey: "test-key", model: "test-model", rewriteNeedThreshold: 0)
        rewriter = OpenRouterTranscriptRewriter(config: config, transport: transport, logger: logger)
        transport.response = .success(OpenRouterTransportResponse(statusCode: 200, body: """
        {
            "choices": [{
                "message": {
                    "content": "this is a test"
                }
            }]
        }
        """.data(using: .utf8)!))

        let result = rewriter.rewrite("this is a test", context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "test"))

        XCTAssertNotNil(result)
        XCTAssertTrue(logger.messages.contains { $0.hasPrefix("smart_rewrite_applied") })
    }

    func testThresholdUpdateShouldBeRespected() {
        config = OpenRouterTranscriptRewriterConfig(apiKey: "test-key", model: "test-model", rewriteNeedThreshold: 5)
        rewriter = OpenRouterTranscriptRewriter(config: config, transport: transport, logger: logger)

        // First attempt, should not rewrite.
        let result1 = rewriter.rewrite("a short test", context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "test"))
        XCTAssertNil(result1)
        XCTAssertTrue(logger.messages.contains { $0.hasPrefix("smart_rewrite_skipped reason=low_need") })

        // Update threshold.
        rewriter.updateRewriteNeedThreshold(1)
        logger.clear()

        transport.response = .success(OpenRouterTransportResponse(statusCode: 200, body: """
        {
            "choices": [{
                "message": {
                    "content": "a short test rewritten"
                }
            }]
        }
        """.data(using: .utf8)!))
        // Second attempt, should rewrite.
        let result2 = rewriter.rewrite("this is a short test", context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: "test"))
        XCTAssertNotNil(result2)
        XCTAssertTrue(logger.messages.contains { $0.hasPrefix("smart_rewrite_applied") })
    }
}

private final class MockTransport: OpenRouterTransporting {
    var response: Result<OpenRouterTransportResponse, Error>?

    func send(request: URLRequest, timeout: TimeInterval) throws -> OpenRouterTransportResponse {
        switch response {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        case .none:
            fatalError("No response provided for MockTransport")
        }
    }
}
