import Foundation

public final class AppleScriptRecordingMediaController: RecordingMediaControlling, @unchecked Sendable {
    public typealias DispatchAsync = (@escaping @Sendable () -> Void) -> Void
    public typealias ScriptRunner = (_ script: String) -> String?

    private enum Player: String, CaseIterable, Hashable {
        case music = "Music"
        case spotify = "Spotify"
    }

    private enum BrowserPlayer: String, CaseIterable, Hashable {
        case chrome = "Google Chrome"
        case arc = "Arc"
        case safari = "Safari"

        var logName: String {
            switch self {
            case .chrome:
                return "chrome"
            case .arc:
                return "arc"
            case .safari:
                return "safari"
            }
        }
    }

    private let queue = DispatchQueue(label: "murmur.recording.media")
    private let logger: Logging
    private let dispatchAsync: DispatchAsync
    private let scriptRunner: ScriptRunner
    private var pausedPlayers: Set<Player> = []
    private var pausedBrowserPlayers: Set<BrowserPlayer> = []
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
            self.pausedPlayers.removeAll(keepingCapacity: true)
            self.pausedBrowserPlayers.removeAll(keepingCapacity: true)
            self.captureAndMuteSystemOutputVolumeIfPossible()
            for player in Player.allCases {
                if self.pauseIfNeeded(player: player) {
                    self.pausedPlayers.insert(player)
                }
            }
            for browser in BrowserPlayer.allCases {
                if self.pauseIfNeeded(browser: browser) {
                    self.pausedBrowserPlayers.insert(browser)
                }
            }
        }
    }

    public func resumeMediaAfterRecording() {
        dispatchAsync {
            let playersToResume = self.pausedPlayers
            let browsersToResume = self.pausedBrowserPlayers
            self.pausedPlayers.removeAll(keepingCapacity: true)
            self.pausedBrowserPlayers.removeAll(keepingCapacity: true)
            for player in playersToResume {
                self.resume(player: player)
            }
            for browser in browsersToResume {
                self.resume(browser: browser)
            }
            self.restoreSystemOutputVolumeIfNeeded()
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

    private func pauseIfNeeded(browser: BrowserPlayer) -> Bool {
        let output = scriptRunner(pauseScript(for: browser))

        if let output, output.hasPrefix("error:") {
            logger.log("media_control_pause_error player=\(browser.logName) details=\"\(escapeLogValue(output))\"")
            return false
        }

        if output == "paused" {
            logger.log("media_control_paused player=\(browser.logName)")
            return true
        }

        logger.log("media_control_pause_noop player=\(browser.logName)")
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

    private func resume(browser: BrowserPlayer) {
        let output = scriptRunner(resumeScript(for: browser))

        if let output, output.hasPrefix("error:") {
            logger.log("media_control_resume_error player=\(browser.logName) details=\"\(escapeLogValue(output))\"")
            return
        }

        if output == "resumed" {
            logger.log("media_control_resumed player=\(browser.logName)")
            return
        }

        logger.log("media_control_resume_noop player=\(browser.logName)")
    }

    private func pauseScript(for browser: BrowserPlayer) -> String {
        switch browser {
        case .chrome:
            return pauseChromiumScript(applicationName: browser.rawValue)
        case .arc:
            return pauseChromiumActiveTabScript(applicationName: browser.rawValue)
        case .safari:
            return pauseSafariScript()
        }
    }

    private func resumeScript(for browser: BrowserPlayer) -> String {
        switch browser {
        case .chrome:
            return resumeChromiumScript(applicationName: browser.rawValue)
        case .arc:
            return resumeChromiumActiveTabScript(applicationName: browser.rawValue)
        case .safari:
            return resumeSafariScript()
        }
    }

    private func pauseChromiumScript(applicationName: String) -> String {
        """
        try
            if application "\(applicationName)" is running then
                tell application "\(applicationName)"
                    set didPause to false
                    repeat with w in windows
                        repeat with t in tabs of w
                            set pauseResult to execute t javascript "(() => { const nodes = Array.from(document.querySelectorAll('video,audio')); let didPause = false; for (const media of nodes) { if (!media.paused) { media.setAttribute('data-murmur-paused', '1'); media.pause(); didPause = true; } } return didPause ? 'paused' : 'noop'; })();"
                            if pauseResult is "paused" then
                                set didPause to true
                            end if
                        end repeat
                    end repeat
                    if didPause then
                        return "paused"
                    end if
                end tell
            end if
        on error errMsg number errNum
            return "error:" & errNum & ":" & errMsg
        end try
        return "noop"
        """
    }

    private func pauseChromiumActiveTabScript(applicationName: String) -> String {
        """
        try
            if application "\(applicationName)" is running then
                tell application "\(applicationName)"
                    if (count of windows) > 0 then
                        set pauseResult to execute active tab of front window javascript "(() => { const nodes = Array.from(document.querySelectorAll('video,audio')); let didPause = false; for (const media of nodes) { if (!media.paused) { media.setAttribute('data-murmur-paused', '1'); media.pause(); didPause = true; } } return didPause ? 'paused' : 'noop'; })();"
                        if pauseResult is "paused" then
                            return "paused"
                        end if
                    end if
                end tell
            end if
        on error errMsg number errNum
            return "error:" & errNum & ":" & errMsg
        end try
        return "noop"
        """
    }

    private func resumeChromiumScript(applicationName: String) -> String {
        """
        try
            if application "\(applicationName)" is running then
                tell application "\(applicationName)"
                    set didResume to false
                    repeat with w in windows
                        repeat with t in tabs of w
                            set resumeResult to execute t javascript "(() => { const nodes = Array.from(document.querySelectorAll('video,audio')); let didResume = false; for (const media of nodes) { if (media.getAttribute('data-murmur-paused') === '1') { media.removeAttribute('data-murmur-paused'); const playResult = media.play(); if (playResult && typeof playResult.catch === 'function') { playResult.catch(() => {}); } didResume = true; } } if (didResume) return 'resumed'; const fallbackMedia = nodes.find((m) => m.paused); if (fallbackMedia) { try { const fallbackPlay = fallbackMedia.play(); if (fallbackPlay && typeof fallbackPlay.catch === 'function') { fallbackPlay.catch(() => {}); } if (!fallbackMedia.paused) return 'resumed'; } catch (_) {} } const fallbackButton = document.querySelector('.ytp-play-button[aria-label*=\"Play\"], .ytp-play-button[title*=\"Play\"], button[aria-label*=\"Play\"], button[title*=\"Play\"]'); if (fallbackButton) { fallbackButton.click(); return 'resumed'; } return 'noop'; })();"
                            if resumeResult is "resumed" then
                                set didResume to true
                            end if
                        end repeat
                    end repeat
                    if didResume then
                        return "resumed"
                    end if
                end tell
            end if
        on error errMsg number errNum
            return "error:" & errNum & ":" & errMsg
        end try
        return "noop"
        """
    }

    private func resumeChromiumActiveTabScript(applicationName: String) -> String {
        """
        try
            if application "\(applicationName)" is running then
                tell application "\(applicationName)"
                    if (count of windows) > 0 then
                        set resumeResult to execute active tab of front window javascript "(() => { const nodes = Array.from(document.querySelectorAll('video,audio')); let didResume = false; for (const media of nodes) { if (media.getAttribute('data-murmur-paused') === '1') { media.removeAttribute('data-murmur-paused'); const playResult = media.play(); if (playResult && typeof playResult.catch === 'function') { playResult.catch(() => {}); } didResume = true; } } if (didResume) return 'resumed'; const fallbackMedia = nodes.find((m) => m.paused); if (fallbackMedia) { try { const fallbackPlay = fallbackMedia.play(); if (fallbackPlay && typeof fallbackPlay.catch === 'function') { fallbackPlay.catch(() => {}); } if (!fallbackMedia.paused) return 'resumed'; } catch (_) {} } const fallbackButton = document.querySelector('.ytp-play-button[aria-label*=\"Play\"], .ytp-play-button[title*=\"Play\"], button[aria-label*=\"Play\"], button[title*=\"Play\"]'); if (fallbackButton) { fallbackButton.click(); return 'resumed'; } return 'noop'; })();"
                        if resumeResult is "resumed" then
                            return "resumed"
                        end if
                    end if
                end tell
            end if
        on error errMsg number errNum
            return "error:" & errNum & ":" & errMsg
        end try
        return "noop"
        """
    }

    private func pauseSafariScript() -> String {
        """
        try
            if application "Safari" is running then
                tell application "Safari"
                    set didPause to false
                    repeat with w in windows
                        repeat with t in tabs of w
                            set pauseResult to do JavaScript "(() => { const nodes = Array.from(document.querySelectorAll('video,audio')); let didPause = false; for (const media of nodes) { if (!media.paused) { media.setAttribute('data-murmur-paused', '1'); media.pause(); didPause = true; } } return didPause ? 'paused' : 'noop'; })();" in t
                            if pauseResult is "paused" then
                                set didPause to true
                            end if
                        end repeat
                    end repeat
                    if didPause then
                        return "paused"
                    end if
                end tell
            end if
        on error errMsg number errNum
            return "error:" & errNum & ":" & errMsg
        end try
        return "noop"
        """
    }

    private func resumeSafariScript() -> String {
        """
        try
            if application "Safari" is running then
                tell application "Safari"
                    set didResume to false
                    repeat with w in windows
                        repeat with t in tabs of w
                            set resumeResult to do JavaScript "(() => { const nodes = Array.from(document.querySelectorAll('video,audio')); let didResume = false; for (const media of nodes) { if (media.getAttribute('data-murmur-paused') === '1') { media.removeAttribute('data-murmur-paused'); const playResult = media.play(); if (playResult && typeof playResult.catch === 'function') { playResult.catch(() => {}); } didResume = true; } } if (didResume) return 'resumed'; const fallbackMedia = nodes.find((m) => m.paused); if (fallbackMedia) { try { const fallbackPlay = fallbackMedia.play(); if (fallbackPlay && typeof fallbackPlay.catch === 'function') { fallbackPlay.catch(() => {}); } if (!fallbackMedia.paused) return 'resumed'; } catch (_) {} } const fallbackButton = document.querySelector('.ytp-play-button[aria-label*=\"Play\"], .ytp-play-button[title*=\"Play\"], button[aria-label*=\"Play\"], button[title*=\"Play\"]'); if (fallbackButton) { fallbackButton.click(); return 'resumed'; } return 'noop'; })();" in t
                            if resumeResult is "resumed" then
                                set didResume to true
                            end if
                        end repeat
                    end repeat
                    if didResume then
                        return "resumed"
                    end if
                end tell
            end if
        on error errMsg number errNum
            return "error:" & errNum & ":" & errMsg
        end try
        return "noop"
        """
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
