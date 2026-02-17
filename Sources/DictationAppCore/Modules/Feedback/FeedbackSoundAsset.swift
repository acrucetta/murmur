import Foundation

public enum FeedbackSoundAsset: String, CaseIterable, Sendable {
    case recordingStart = "feedback_start"
    case recordingStop = "feedback_stop"

    public var fileExtension: String {
        "wav"
    }

    public var resourceURL: URL? {
        Bundle.module.url(forResource: rawValue, withExtension: fileExtension)
    }
}
