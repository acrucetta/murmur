import Foundation

public protocol TextPostProcessing {
    func clean(_ text: String) -> String
}

public struct TextPostProcessorV2: TextPostProcessing {
    public enum Mode: Sendable {
        case smart
        case literal
    }

    private let mode: Mode

    private static let duplicateCollapseWords: Set<String> = [
        "a", "an", "am", "and", "are", "as", "at", "be", "been", "but", "by", "can", "could", "did",
        "do", "does", "for", "had", "has", "have", "he", "her", "his", "i", "in", "is", "it", "its",
        "me", "my", "of", "on", "or", "our", "she", "should", "that", "the", "their", "them", "there",
        "they", "this", "to", "was", "we", "were", "will", "with", "would", "you", "your",
    ]

    private static let sentenceBoundaryPunctuation: Set<Character> = [".", "!", "?"]
    private static let clauseBoundaryPunctuation: Set<Character> = [".", "!", "?", ",", ";", ":"]
    private static let spokenSymbolMarkers: [([String], String)] = [
        (["exclamation", "mark"], "!"),
        (["exclamation", "point"], "!"),
        (["question", "mark"], "?"),
        (["question", "point"], "?"),
        (["at", "sign"], "@"),
        (["at", "symbol"], "@"),
    ]

    public init(mode: Mode = .smart) {
        self.mode = mode
    }

    public func clean(_ text: String) -> String {
        let normalizedWhitespace = normalizeWhitespace(text)
        guard !normalizedWhitespace.isEmpty else {
            return ""
        }

        let tokens = normalizedWhitespace
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        let symbolAware = applySpokenSymbols(tokens)

        let processed: String
        switch mode {
        case .literal:
            processed = joinTokens(symbolAware)
        case .smart:
            let repaired = applyRepairMarkers(symbolAware)
            let deduped = collapseRepetitions(repaired)
            processed = joinTokens(deduped)
        }

        return finalizeSentence(processed)
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applySpokenSymbols(_ originalTokens: [String]) -> [String] {
        var tokens = originalTokens

        for (marker, symbol) in Self.spokenSymbolMarkers {
            tokens = replaceMarker(marker, with: symbol, in: tokens)
        }

        return tokens
    }

    private func replaceMarker(_ marker: [String], with replacement: String, in originalTokens: [String]) -> [String] {
        var tokens = originalTokens

        while let markerStart = firstMarkerIndex(tokens: tokens, marker: marker) {
            let markerEnd = markerStart + marker.count
            guard markerEnd <= tokens.count else {
                break
            }
            tokens.replaceSubrange(markerStart..<markerEnd, with: [replacement])
        }

        return tokens
    }

    private func applyRepairMarkers(_ originalTokens: [String]) -> [String] {
        var tokens = originalTokens
        tokens = applyStrongMarker(["scratch", "that"], on: tokens)
        tokens = applyStrongMarker(["no", "wait"], on: tokens)
        tokens = applyIMeanMarker(tokens)
        tokens = applyActuallyMarker(tokens)
        return tokens
    }

    private func applyStrongMarker(_ marker: [String], on originalTokens: [String]) -> [String] {
        var tokens = originalTokens

        while let markerStart = firstMarkerIndex(tokens: tokens, marker: marker) {
            let markerEnd = markerStart + marker.count
            guard markerEnd <= tokens.count else {
                break
            }

            if markerEnd == tokens.count {
                tokens.removeSubrange(markerStart..<markerEnd)
                continue
            }

            let sentenceStart = nearestSentenceStart(before: markerStart, in: tokens)
            let prefix = Array(tokens[..<sentenceStart])
            let suffix = Array(tokens[markerEnd...])
            tokens = prefix + suffix
        }

        return tokens
    }

    private func applyIMeanMarker(_ originalTokens: [String]) -> [String] {
        var tokens = originalTokens
        let marker = ["i", "mean"]

        while let markerStart = firstMarkerIndex(tokens: tokens, marker: marker) {
            let markerEnd = markerStart + marker.count
            guard markerEnd <= tokens.count else {
                break
            }

            if markerStart == 0 {
                tokens.removeSubrange(markerStart..<markerEnd)
                continue
            }

            let tokenBeforeMarker = tokens[markerStart - 1]
            let previousCanonical = canonicalToken(tokenBeforeMarker)
            let nextCanonical = markerEnd < tokens.count ? canonicalToken(tokens[markerEnd]) : ""
            let shouldDropPreviousToken = !isClauseBoundary(tokenBeforeMarker)
                && !previousCanonical.isEmpty
                && !Self.duplicateCollapseWords.contains(previousCanonical)
                && !nextCanonical.isEmpty
                && !Self.duplicateCollapseWords.contains(nextCanonical)
            let removeStart = shouldDropPreviousToken ? markerStart - 1 : markerStart
            tokens.removeSubrange(removeStart..<markerEnd)
        }

        return tokens
    }

    private func applyActuallyMarker(_ originalTokens: [String]) -> [String] {
        var tokens = originalTokens

        var index = 0
        while index < tokens.count {
            let canonical = canonicalToken(tokens[index])
            guard canonical == "actually" else {
                index += 1
                continue
            }

            if index == 0 {
                tokens.remove(at: index)
                continue
            }

            let previousCanonical = canonicalToken(tokens[index - 1])
            let nextCanonical = index + 1 < tokens.count ? canonicalToken(tokens[index + 1]) : ""
            let shouldReplacePreviousWord = !previousCanonical.isEmpty
                && !Self.duplicateCollapseWords.contains(previousCanonical)
                && !isClauseBoundary(tokens[index - 1])
                && !nextCanonical.isEmpty
                && !Self.duplicateCollapseWords.contains(nextCanonical)
                && index + 1 < tokens.count

            if shouldReplacePreviousWord {
                tokens.removeSubrange((index - 1)...index)
                index = max(0, index - 1)
                continue
            }

            tokens.remove(at: index)
        }

        return tokens
    }

    private func collapseRepetitions(_ originalTokens: [String]) -> [String] {
        var result: [String] = []
        var previousCanonical = ""
        var duplicateRunLength = 0

        for token in originalTokens {
            let canonical = canonicalToken(token)
            guard !canonical.isEmpty else {
                result.append(token)
                previousCanonical = ""
                duplicateRunLength = 0
                continue
            }

            let hasBoundary = result.last.map { isClauseBoundary($0) } ?? false
            if !hasBoundary, canonical == previousCanonical {
                duplicateRunLength += 1
                if shouldDropDuplicate(canonical, runLength: duplicateRunLength) {
                    continue
                }
            } else {
                duplicateRunLength = 1
            }

            result.append(token)
            previousCanonical = canonical
        }

        return result
    }

    private func shouldDropDuplicate(_ canonical: String, runLength: Int) -> Bool {
        if Self.duplicateCollapseWords.contains(canonical) {
            return true
        }

        // Keep optional emphasis doubles by default, but collapse long stutters.
        return runLength >= 3
    }

    private func joinTokens(_ tokens: [String]) -> String {
        let atJoinedTokens = tightenAtSymbolTokens(tokens)
        let joined = atJoinedTokens.joined(separator: " ")
        return joined.replacingOccurrences(
            of: "\\s+([,.;:!?])",
            with: "$1",
            options: .regularExpression
        )
    }

    private func tightenAtSymbolTokens(_ originalTokens: [String]) -> [String] {
        var result: [String] = []
        var index = 0

        while index < originalTokens.count {
            let current = originalTokens[index]
            if current == "@",
               let previous = result.last,
               index + 1 < originalTokens.count
            {
                let next = originalTokens[index + 1]
                if shouldJoinAroundAt(previous: previous, next: next) {
                    result[result.count - 1] = previous + "@" + next
                    index += 2
                    continue
                }
            }

            result.append(current)
            index += 1
        }

        return result
    }

    private func shouldJoinAroundAt(previous: String, next: String) -> Bool {
        isEmailLocalPart(previous) && isDomainLikeToken(next)
    }

    private func isEmailLocalPart(_ token: String) -> Bool {
        let canonical = canonicalToken(token)
        guard !canonical.isEmpty else {
            return false
        }

        return canonical.range(of: "^[a-z0-9][a-z0-9._%+\\-]*$", options: .regularExpression) != nil
    }

    private func isDomainLikeToken(_ token: String) -> Bool {
        let canonical = canonicalToken(token)
        guard canonical.contains(".") else {
            return false
        }

        return canonical.range(of: "^[a-z0-9][a-z0-9._\\-]*\\.[a-z0-9._\\-]+$", options: .regularExpression) != nil
    }

    private func finalizeSentence(_ text: String) -> String {
        let collapsed = normalizeWhitespace(text)
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

    private func firstMarkerIndex(tokens: [String], marker: [String]) -> Int? {
        guard marker.count <= tokens.count else {
            return nil
        }

        let canonicalTokens = tokens.map(canonicalToken)
        for start in 0...(tokens.count - marker.count) {
            let candidate = Array(canonicalTokens[start..<(start + marker.count)])
            if candidate == marker {
                return start
            }
        }
        return nil
    }

    private func nearestSentenceStart(before index: Int, in tokens: [String]) -> Int {
        guard index > 0 else {
            return 0
        }

        for cursor in stride(from: index - 1, through: 0, by: -1) {
            if let last = tokens[cursor].last, Self.sentenceBoundaryPunctuation.contains(last) {
                return cursor + 1
            }
        }
        return 0
    }

    private func isClauseBoundary(_ token: String) -> Bool {
        guard let last = token.last else {
            return false
        }
        return Self.clauseBoundaryPunctuation.contains(last)
    }

    private func canonicalToken(_ token: String) -> String {
        token
            .lowercased()
            .replacingOccurrences(of: "^[^a-z0-9']+|[^a-z0-9']+$", with: "", options: .regularExpression)
    }
}
