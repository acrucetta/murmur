import Foundation

public struct TranscriptHistoryEntry: Equatable, Sendable {
    public let timestamp: Date
    public let transcript: String
    public let insertResult: InsertResult

    public init(timestamp: Date, transcript: String, insertResult: InsertResult) {
        self.timestamp = timestamp
        self.transcript = transcript
        self.insertResult = insertResult
    }
}

public protocol TranscriptHistoryWriting {
    func record(_ entry: TranscriptHistoryEntry)
}

public struct NoopTranscriptHistoryWriter: TranscriptHistoryWriting {
    public init() {}

    public func record(_ entry: TranscriptHistoryEntry) {}
}

public final class FileTranscriptHistoryStore: TranscriptHistoryWriting {
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue
    private let dayFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    public init(baseDirectory: URL = FileTranscriptHistoryStore.defaultDirectoryURL(), fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
        self.queue = DispatchQueue(label: "murmur.transcript-history")

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = dayFormatter

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm:ss"
        self.timeFormatter = timeFormatter
    }

    public static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Murmur", isDirectory: true)
            .appendingPathComponent("transcriptions", isDirectory: true)
    }

    public func record(_ entry: TranscriptHistoryEntry) {
        queue.sync {
            let cleanedText = normalize(entry.transcript)
            guard !cleanedText.isEmpty else {
                return
            }

            let day = dayFormatter.string(from: entry.timestamp)
            let fileURL = baseDirectory.appendingPathComponent("\(day).txt")
            let line = formatLine(entry: entry, cleanedText: cleanedText)

            do {
                try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
                if !fileManager.fileExists(atPath: fileURL.path) {
                    fileManager.createFile(atPath: fileURL.path, contents: nil)
                }

                let data = Data(line.utf8)
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                return
            }
        }
    }

    private func formatLine(entry: TranscriptHistoryEntry, cleanedText: String) -> String {
        let time = timeFormatter.string(from: entry.timestamp)
        let status = entry.insertResult.success ? "ok" : "fail"
        let method = entry.insertResult.method.rawValue

        var line = "[\(time)] [\(status)] [\(method)] \(cleanedText)"
        if let failure = entry.insertResult.error {
            line += " [\(failure.rawValue)]"
        }
        line += "\n"
        return line
    }

    private func normalize(_ transcript: String) -> String {
        transcript
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
