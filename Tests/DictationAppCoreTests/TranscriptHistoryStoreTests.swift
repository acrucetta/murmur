import Foundation
import Testing
@testable import DictationAppCore

struct TranscriptHistoryStoreTests {
    @Test
    func recordsEntryInDailyHistoryFile() throws {
        let baseDirectory = uniqueTempDirectory()
        let store = FileTranscriptHistoryStore(baseDirectory: baseDirectory)
        let timestamp = Date(timeIntervalSince1970: 1_771_328_800) // 2026-02-17 12:00:00 UTC

        store.record(
            .init(
                timestamp: timestamp,
                transcript: "Hello from transcript history.",
                insertResult: .init(success: true, method: .accessibilityDirect, error: nil)
            )
        )

        let fileURL = baseDirectory.appendingPathComponent("2026-02-17.txt")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(contents.contains("Hello from transcript history."))
        #expect(contents.contains("accessibility_direct"))
        #expect(contents.contains("ok"))
    }

    @Test
    func appendsMultipleEntriesToSameDayFile() throws {
        let baseDirectory = uniqueTempDirectory()
        let store = FileTranscriptHistoryStore(baseDirectory: baseDirectory)
        let timestamp = Date(timeIntervalSince1970: 1_771_328_800)

        store.record(
            .init(
                timestamp: timestamp,
                transcript: "First entry.",
                insertResult: .init(success: true, method: .accessibilityDirect, error: nil)
            )
        )
        store.record(
            .init(
                timestamp: timestamp.addingTimeInterval(5),
                transcript: "Second entry.",
                insertResult: .init(success: false, method: .clipboardPaste, error: .insertionFailed)
            )
        )

        let fileURL = baseDirectory.appendingPathComponent("2026-02-17.txt")
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(contents.contains("First entry."))
        #expect(contents.contains("Second entry."))
        #expect(contents.contains("fail"))
        #expect(contents.contains("insertion_failed"))
    }
}

private func uniqueTempDirectory() -> URL {
    let root = FileManager.default.temporaryDirectory
    let directory = root.appendingPathComponent("murmur-transcript-history-tests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
