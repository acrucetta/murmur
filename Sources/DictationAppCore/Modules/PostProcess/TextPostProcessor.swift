import Foundation

public protocol TextPostProcessing {
    func clean(_ text: String) -> String
}

public struct DeterministicTextPostProcessor: TextPostProcessing {
    public init() {}

    public func clean(_ text: String) -> String {
        let collapsed = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else {
            return ""
        }

        let first = collapsed.prefix(1).uppercased()
        let remainder = collapsed.dropFirst()
        var normalized = "\(first)\(remainder)"

        if !normalized.hasSuffix("."),
           !normalized.hasSuffix("!"),
           !normalized.hasSuffix("?") {
            normalized += "."
        }

        return normalized
    }
}
