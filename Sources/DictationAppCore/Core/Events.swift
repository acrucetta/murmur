import Foundation

public struct ShortcutPressed: Equatable, Sendable {
    public let timestamp: Date

    public init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

public struct ShortcutReleased: Equatable, Sendable {
    public let timestamp: Date

    public init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

public struct AudioFrame: Equatable, Sendable {
    public let samples: [Float]
    public let sampleRate: Double
    public let channels: Int

    public init(samples: [Float], sampleRate: Double, channels: Int) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

public struct PartialTranscript: Equatable, Sendable {
    public let text: String
    public let confidence: Double?

    public init(text: String, confidence: Double?) {
        self.text = text
        self.confidence = confidence
    }
}

public struct FinalTranscript: Equatable, Sendable {
    public let text: String
    public let confidence: Double?

    public init(text: String, confidence: Double?) {
        self.text = text
        self.confidence = confidence
    }
}

public enum InsertMethod: String, Equatable, Sendable {
    case accessibilityDirect = "accessibility_direct"
    case clipboardPaste = "clipboard_paste"
}

public enum FailureCode: String, Equatable, Sendable {
    case permissionDenied = "permission_denied"
    case noFocusedField = "no_focused_field"
    case secureInputBlocked = "secure_input_blocked"
    case engineError = "engine_error"
    case insertionFailed = "insertion_failed"
}

public struct InsertResult: Equatable, Sendable {
    public let success: Bool
    public let method: InsertMethod
    public let error: FailureCode?

    public init(success: Bool, method: InsertMethod, error: FailureCode?) {
        self.success = success
        self.method = method
        self.error = error
    }
}

public enum SessionEvent: Equatable, Sendable {
    case shortcutPressed(ShortcutPressed)
    case shortcutReleased(ShortcutReleased)
    case audioFrame(AudioFrame)
    case partialTranscript(PartialTranscript)
    case finalTranscript(FinalTranscript)
    case insertResult(InsertResult)
    case reset
}
