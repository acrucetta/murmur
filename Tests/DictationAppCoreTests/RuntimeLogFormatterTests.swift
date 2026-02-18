import Foundation
import Testing
@testable import DictationAppCore

struct RuntimeLogFormatterTests {
    @Test
    func prependsTimestampAndLevelToLogLine() {
        let date = Date(timeIntervalSince1970: 1_739_379_600.125)

        let line = RuntimeLogFormatter.format("metric smart_rewrite_applied elapsed_ms=42", now: date)

        #expect(line.hasPrefix("ts="))
        #expect(line.contains(" level=info metric smart_rewrite_applied elapsed_ms=42"))
        #expect(line.hasSuffix("metric smart_rewrite_applied elapsed_ms=42"))
    }

    @Test
    func escapesEmbeddedNewlines() {
        let line = RuntimeLogFormatter.format("details=line1\nline2")
        #expect(line.contains("details=line1\\nline2"))
    }
}
