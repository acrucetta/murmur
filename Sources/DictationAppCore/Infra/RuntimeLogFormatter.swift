import Foundation

public enum RuntimeLogFormatter {
    public static func format(_ line: String, level: String = "info", now: Date = Date()) -> String {
        let timestamp = timestampString(from: now)
        let sanitizedLine = line.replacingOccurrences(of: "\n", with: "\\n")
        return "ts=\(timestamp) level=\(level) \(sanitizedLine)"
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
