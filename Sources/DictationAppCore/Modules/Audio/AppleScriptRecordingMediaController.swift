import Foundation

public final class AppleScriptRecordingMediaController: RecordingMediaControlling, @unchecked Sendable {
    public typealias DispatchAsync = (@escaping @Sendable () -> Void) -> Void
    public typealias ScriptRunner = (_ script: String) -> String?

    private enum Player: String, CaseIterable, Hashable {
        case music = "Music"
        case spotify = "Spotify"
    }

    private let queue = DispatchQueue(label: "murmur.recording.media")
    private let logger: Logging
    private let dispatchAsync: DispatchAsync
    private let scriptRunner: ScriptRunner
    private var pausedPlayers: Set<Player> = []

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
            self.pausedPlayers.removeAll(keepingCapacity: true)
            for player in Player.allCases {
                if self.pauseIfNeeded(player: player) {
                    self.pausedPlayers.insert(player)
                }
            }
        }
    }

    public func resumeMediaAfterRecording() {
        dispatchAsync {
            let playersToResume = self.pausedPlayers
            self.pausedPlayers.removeAll(keepingCapacity: true)
            for player in playersToResume {
                self.resume(player: player)
            }
        }
    }

    private func pauseIfNeeded(player: Player) -> Bool {
        let output = scriptRunner(
            """
            try
                if application "\(player.rawValue)" is running then
                    tell application "\(player.rawValue)"
                        if player state is playing then
                            pause
                            return "paused"
                        end if
                    end tell
                end if
            on error errMsg number errNum
                return "error:" & errNum & ":" & errMsg
            end try
            return "noop"
            """
        )

        if let output, output.hasPrefix("error:") {
            logger.log("media_control_pause_error player=\(player.rawValue.lowercased()) details=\"\(escapeLogValue(output))\"")
            return false
        }

        if output == "paused" {
            logger.log("media_control_paused player=\(player.rawValue.lowercased())")
            return true
        }

        logger.log("media_control_pause_noop player=\(player.rawValue.lowercased())")
        return false
    }

    private func resume(player: Player) {
        let output = scriptRunner(
            """
            try
                if application "\(player.rawValue)" is running then
                    tell application "\(player.rawValue)"
                        if player state is paused then
                            play
                            return "resumed"
                        end if
                    end tell
                end if
            on error errMsg number errNum
                return "error:" & errNum & ":" & errMsg
            end try
            return "noop"
            """
        )

        if let output, output.hasPrefix("error:") {
            logger.log("media_control_resume_error player=\(player.rawValue.lowercased()) details=\"\(escapeLogValue(output))\"")
            return
        }

        if output == "resumed" {
            logger.log("media_control_resumed player=\(player.rawValue.lowercased())")
            return
        }

        logger.log("media_control_resume_noop player=\(player.rawValue.lowercased())")
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
