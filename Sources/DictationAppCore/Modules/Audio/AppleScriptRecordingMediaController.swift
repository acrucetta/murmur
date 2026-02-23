import Foundation

public final class AppleScriptRecordingMediaController: RecordingMediaControlling, @unchecked Sendable {
    public typealias DispatchAsync = (@escaping @Sendable () -> Void) -> Void
    public typealias ScriptRunner = (_ script: String) -> String?

    private let queue = DispatchQueue(label: "murmur.recording.media")
    private let logger: Logging
    private let dispatchAsync: DispatchAsync
    private let scriptRunner: ScriptRunner
    private var preRecordingOutputVolume: Int?
    private var preRecordingOutputMuted: Bool?

    public init(
        logger: Logging,
        dispatchAsync: DispatchAsync? = nil,
        scriptRunner: ScriptRunner? = nil
    ) {
        self.logger = logger
        self.dispatchAsync = dispatchAsync ?? { [queue] work in
            queue.async {
                work()
            }
        }
        self.scriptRunner = scriptRunner ?? { [logger] script in
            Self.runAppleScript(script, logger: logger)
        }
    }

    public func pauseMediaForRecording() {
        dispatchAsync {
            self.captureAndMuteSystemOutputVolumeIfPossible()
        }
    }

    public func resumeMediaAfterRecording() {
        dispatchAsync {
            self.restoreSystemOutputVolumeIfNeeded()
        }
    }

    private func captureAndMuteSystemOutputVolumeIfPossible() {
        let output = scriptRunner(
            """
            try
                set currentVolume to output volume of (get volume settings)
                set isMuted to output muted of (get volume settings)
                return (currentVolume as string) & "|" & (isMuted as string)
            on error errMsg number errNum
                return "error:" & errNum & ":" & errMsg
            end try
            """
        )

        guard let output else {
            return
        }
        if output.hasPrefix("error:") {
            logger.log("media_control_volume_capture_error details=\"\(escapeLogValue(output))\"")
            return
        }

        let pieces = output.split(separator: "|", maxSplits: 1).map(String.init)
        guard pieces.count == 2,
              let volume = Int(pieces[0]),
              let muted = parseAppleScriptBool(pieces[1])
        else {
            logger.log("media_control_volume_capture_error details=\"invalid_state:\(escapeLogValue(output))\"")
            return
        }

        preRecordingOutputVolume = volume
        preRecordingOutputMuted = muted

        let muteResult = scriptRunner(
            """
            try
                set volume output volume 0
                return "muted"
            on error errMsg number errNum
                return "error:" & errNum & ":" & errMsg
            end try
            """
        )

        if let muteResult, muteResult.hasPrefix("error:") {
            logger.log("media_control_volume_mute_error details=\"\(escapeLogValue(muteResult))\"")
            return
        }

        logger.log("media_control_volume_muted previous_volume=\(volume) previous_muted=\(muted)")
    }

    private func restoreSystemOutputVolumeIfNeeded() {
        guard let volume = preRecordingOutputVolume,
              let muted = preRecordingOutputMuted
        else {
            return
        }
        preRecordingOutputVolume = nil
        preRecordingOutputMuted = nil

        let mutedLiteral = muted ? "true" : "false"
        let restoreResult = scriptRunner(
            """
            try
                set volume output volume \(volume) output muted \(mutedLiteral)
                return "restored"
            on error errMsg number errNum
                return "error:" & errNum & ":" & errMsg
            end try
            """
        )

        if let restoreResult, restoreResult.hasPrefix("error:") {
            logger.log("media_control_volume_restore_error details=\"\(escapeLogValue(restoreResult))\"")
            return
        }

        logger.log("media_control_volume_restored restored_volume=\(volume) restored_muted=\(muted)")
    }

    private func parseAppleScriptBool(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }


    private static func runAppleScript(_ script: String, logger: Logging) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.log("media_control_runner_failed error=\"\(escapeLogValue(error.localizedDescription))\"")
            return nil
        }

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            if let errorText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !errorText.isEmpty
            {
                logger.log(
                    "media_control_script_failed status=\(process.terminationStatus) details=\"\(escapeLogValue(errorText))\""
                )
            }
            return nil
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == true ? nil : output
    }

    private static func escapeLogValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private func escapeLogValue(_ value: String) -> String {
        Self.escapeLogValue(value)
    }
}
