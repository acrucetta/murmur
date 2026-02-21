import Foundation

public final class SessionOrchestrator {
    public typealias NowProvider = () -> Date
    private static let minimumSmartRewriteDurationMilliseconds = 350
    private static let minimumSmartRewriteNeedScore = 3
    private static let longTranscriptCharacterThreshold = 220
    private static let longTranscriptTokenThreshold = 36
    private static let runOnCandidateTokenThreshold = 24

    private let stateMachine: StateMachine
    private let permissionManager: PermissionManaging
    private let audioCapture: AudioCapturing
    private let asrEngine: ASREngining
    private let postProcessor: TextPostProcessing
    private let transcriptRewriter: TranscriptRewriting
    private let rewriteContextProvider: RewriteContextProviding
    private let fieldWriter: FocusedFieldWriting
    private let statusUI: StatusPresenting
    private let feedback: FeedbackPresenting
    private let recordingMediaController: RecordingMediaControlling
    private let transcriptHistory: TranscriptHistoryWriting
    private let logger: Logging
    private let now: NowProvider
    private var shortcutPressTimestamp: Date?
    private var releaseTimestamp: Date?
    private var hasLoggedFirstAudioFrameLatency = false
    private var capturedFrameCount = 0
    private var capturedSampleCount = 0
    private var capturedDurationSeconds: Double = 0
    private var capturedRMSAccumulator: Double = 0
    private var capturedPeakRMS: Float = 0

    public private(set) var state: SessionState = .idle {
        didSet {
            statusUI.update(state: state)
        }
    }

    public init(
        permissionManager: PermissionManaging,
        audioCapture: AudioCapturing,
        asrEngine: ASREngining,
        postProcessor: TextPostProcessing,
        transcriptRewriter: TranscriptRewriting = NoopTranscriptRewriter(),
        rewriteContextProvider: RewriteContextProviding = StaticRewriteContextProvider(
            context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: TranscriptRewriteMode.literal.rawValue)
        ),
        fieldWriter: FocusedFieldWriting,
        statusUI: StatusPresenting,
        feedback: FeedbackPresenting = NoopFeedbackPresenter(),
        recordingMediaController: RecordingMediaControlling = NoopRecordingMediaController(),
        transcriptHistory: TranscriptHistoryWriting = NoopTranscriptHistoryWriter(),
        logger: Logging,
        now: @escaping NowProvider = Date.init,
        stateMachine: StateMachine = .init()
    ) {
        self.permissionManager = permissionManager
        self.audioCapture = audioCapture
        self.asrEngine = asrEngine
        self.postProcessor = postProcessor
        self.transcriptRewriter = transcriptRewriter
        self.rewriteContextProvider = rewriteContextProvider
        self.fieldWriter = fieldWriter
        self.statusUI = statusUI
        self.feedback = feedback
        self.recordingMediaController = recordingMediaController
        self.transcriptHistory = transcriptHistory
        self.logger = logger
        self.now = now
        self.stateMachine = stateMachine
    }

    public func handle(_ event: SessionEvent) {
        switch event {
        case .shortcutPressed:
            handleShortcutPressed(event)
        case .shortcutReleased:
            transition(event)
            if state == .finalizing {
                feedback.recordingDidStop()
                recordingMediaController.resumeMediaAfterRecording()
                releaseTimestamp = releaseDate(from: event)
                audioCapture.stop()
                let finalTranscript = asrEngine.stopAndFinalize()
                if let finalTranscript {
                    handle(.finalTranscript(finalTranscript))
                } else if asrEngine.providesFinalTranscriptOnStop {
                    statusUI.showError(.engineError)
                    state = .error(.engineError)
                    let reason = engineFinalizeFailureReason()
                    logger.log("engine finalize failed: no transcript produced\(reason)\(captureDiagnosticsSummary())")
                }
            }
        case .audioFrame(let audioFrame):
            guard state == .listening else {
                return
            }
            logShortcutToFirstAudioFrameLatencyIfNeeded()
            asrEngine.consume(audioFrame)
            recordAudioCaptureDiagnostics(for: audioFrame)
        case .partialTranscript(let partialTranscript):
            guard state == .listening else {
                return
            }
            statusUI.showPartialTranscript(partialTranscript.text)
        case .finalTranscript(let finalTranscript):
            transition(event)
            if state == .inserting {
                logReleaseToFinalLatencyIfPossible()
                let cleaned = postProcessor.clean(finalTranscript.text)
                let rewriteContext = rewriteContextProvider.currentContext()
                logRewriteInput(cleaned, mode: rewriteContext.mode)
                let rewritten: String?
                if shouldSkipSmartRewriteForShortRecording(mode: rewriteContext.mode) {
                    rewritten = nil
                } else if shouldSkipSmartRewriteForLowNeed(mode: rewriteContext.mode, text: cleaned) {
                    rewritten = nil
                } else {
                    rewritten = transcriptRewriter
                        .rewrite(cleaned, context: rewriteContext)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let textToInsert: String
                if let rewritten, !rewritten.isEmpty {
                    logRewriteOutput(rewritten, source: "llm", changed: rewritten != cleaned)
                    textToInsert = rewritten
                } else {
                    logRewriteOutput(cleaned, source: "original", changed: false)
                    textToInsert = cleaned
                }
                logInsertTextPreview(textToInsert)
                let insertResult = fieldWriter.insert(textToInsert)
                logInsertResult(insertResult)
                transcriptHistory.record(
                    .init(
                        timestamp: releaseTimestamp ?? now(),
                        transcript: textToInsert,
                        insertResult: insertResult
                    )
                )
                handle(.insertResult(insertResult))
            }
        case .insertResult:
            transition(event)
            logReleaseToInsertLatencyIfPossible()
            if case .error(let failureCode) = state {
                statusUI.showError(failureCode)
            }
            if state == .idle || isErrorState(state) {
                releaseTimestamp = nil
            }
        case .reset:
            transition(event)
        }
    }

    private func handleShortcutPressed(_ event: SessionEvent) {
        if state == .listening {
            return
        }

        if isErrorState(state) {
            transition(.reset)
        }

        clearPressSideLatencyState()
        let permissions = permissionManager.currentStatus()
        guard permissions.allGranted else {
            permissionManager.requestMissingPermissions()
            statusUI.showPermissionPrompt(permissions)
            statusUI.showError(.permissionDenied)
            state = .error(.permissionDenied)
            logger.log("permission check failed: \(permissions)")
            return
        }

        transition(event)
        if state == .listening {
            shortcutPressTimestamp = pressDate(from: event)
            logShortcutLatencyIfPossible(label: "shortcut_to_listening_ms")
            recordingMediaController.pauseMediaForRecording()
            resetCaptureDiagnostics()
            let asrStartBeganAt = now()
            asrEngine.start()
            logOperationDuration(startedAt: asrStartBeganAt, label: "asr_start_duration_ms")
            let audioCaptureStartBeganAt = now()
            audioCapture.start()
            logOperationDuration(startedAt: audioCaptureStartBeganAt, label: "audio_capture_start_duration_ms")
            logShortcutLatencyIfPossible(label: "shortcut_to_audio_start_ms")
            let feedbackDispatchBeganAt = now()
            feedback.recordingDidStart()
            logOperationDuration(startedAt: feedbackDispatchBeganAt, label: "feedback_dispatch_duration_ms")
            logShortcutLatencyIfPossible(label: "shortcut_to_feedback_dispatch_ms")
        }
    }

    private func transition(_ event: SessionEvent) {
        state = stateMachine.nextState(from: state, event: event)
    }

    private func releaseDate(from event: SessionEvent) -> Date? {
        guard case .shortcutReleased(let released) = event else {
            return nil
        }
        return released.timestamp
    }

    private func pressDate(from event: SessionEvent) -> Date? {
        guard case .shortcutPressed(let pressed) = event else {
            return nil
        }
        return pressed.timestamp
    }

    private func logShortcutToFirstAudioFrameLatencyIfNeeded() {
        guard !hasLoggedFirstAudioFrameLatency else {
            return
        }
        logShortcutLatencyIfPossible(label: "shortcut_to_first_audio_frame_ms")
        hasLoggedFirstAudioFrameLatency = true
    }

    private func logShortcutLatencyIfPossible(label: String) {
        guard let shortcutPressTimestamp else {
            return
        }
        let elapsed = now().timeIntervalSince(shortcutPressTimestamp)
        let milliseconds = max(0, Int((elapsed * 1000).rounded()))
        logger.log("\(label)=\(milliseconds)")
    }

    private func logOperationDuration(startedAt: Date, label: String) {
        let elapsed = now().timeIntervalSince(startedAt)
        let milliseconds = max(0, Int((elapsed * 1000).rounded()))
        logger.log("\(label)=\(milliseconds)")
    }

    private func clearPressSideLatencyState() {
        shortcutPressTimestamp = nil
        hasLoggedFirstAudioFrameLatency = false
    }

    private func logReleaseToFinalLatencyIfPossible() {
        guard let releaseTimestamp else {
            return
        }
        let elapsed = now().timeIntervalSince(releaseTimestamp)
        let milliseconds = max(0, Int((elapsed * 1000).rounded()))
        logger.log("release_to_final_ms=\(milliseconds)")
    }

    private func logReleaseToInsertLatencyIfPossible() {
        guard let releaseTimestamp else {
            return
        }
        let elapsed = now().timeIntervalSince(releaseTimestamp)
        let milliseconds = max(0, Int((elapsed * 1000).rounded()))
        logger.log("release_to_insert_ms=\(milliseconds)")
    }

    private func logInsertTextPreview(_ text: String) {
        let preview = escapedPreview(for: text, maxLength: 200)
        logger.log("insert_text chars=\(text.count) preview=\"\(preview)\"")
    }

    private func logRewriteInput(_ text: String, mode: String) {
        let modePreview = escapedPreview(for: mode, maxLength: 32)
        let textPreview = escapedPreview(for: text, maxLength: 200)
        logger.log("rewrite_input mode=\"\(modePreview)\" chars=\(text.count) preview=\"\(textPreview)\"")
    }

    private func logRewriteOutput(_ text: String, source: String, changed: Bool) {
        let textPreview = escapedPreview(for: text, maxLength: 200)
        logger.log("rewrite_output source=\(source) changed=\(changed) chars=\(text.count) preview=\"\(textPreview)\"")
    }

    private func logInsertResult(_ result: InsertResult) {
        let code = result.error?.rawValue ?? "none"
        logger.log("insert_result success=\(result.success) method=\(result.method.rawValue) code=\(code)")
    }

    private func escapedPreview(for text: String, maxLength: Int) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        guard escaped.count > maxLength else {
            return escaped
        }
        return String(escaped.prefix(maxLength)) + "..."
    }

    private func engineFinalizeFailureReason() -> String {
        if let moonshineEngine = asrEngine as? MoonshineProcessASREngine,
           let lastError = moonshineEngine.lastError
        {
            return " reason=\(lastError)"
        }
        return ""
    }

    private func recordAudioCaptureDiagnostics(for frame: AudioFrame) {
        capturedFrameCount += 1
        capturedSampleCount += frame.samples.count
        capturedDurationSeconds += frameDurationSeconds(frame)

        guard !frame.samples.isEmpty else {
            return
        }

        var squareSum: Double = 0
        var peak: Float = 0
        for sample in frame.samples {
            let absolute = Swift.abs(sample)
            peak = max(peak, absolute)
            let sampleDouble = Double(sample)
            squareSum += sampleDouble * sampleDouble
        }

        let rms = sqrt(squareSum / Double(frame.samples.count))
        capturedRMSAccumulator += rms
        capturedPeakRMS = max(capturedPeakRMS, peak)
    }

    private func captureDiagnosticsSummary() -> String {
        let averageRMS: Double
        if capturedFrameCount > 0 {
            averageRMS = capturedRMSAccumulator / Double(capturedFrameCount)
        } else {
            averageRMS = 0
        }
        let quality = captureQualityLabel()

        return " captured_frames=\(capturedFrameCount)" +
            " captured_samples=\(capturedSampleCount)" +
            " captured_duration_ms=\(captureDurationMilliseconds())" +
            " captured_avg_rms=\(formatCaptureValue(averageRMS))" +
            " captured_peak_rms=\(formatCaptureValue(Double(capturedPeakRMS)))" +
            " captured_quality=\(quality)"
    }

    private func formatCaptureValue(_ value: Double) -> String {
        String(format: "%.5f", value)
    }

    private func resetCaptureDiagnostics() {
        capturedFrameCount = 0
        capturedSampleCount = 0
        capturedDurationSeconds = 0
        capturedRMSAccumulator = 0
        capturedPeakRMS = 0
    }

    private func shouldSkipSmartRewriteForShortRecording(mode: String) -> Bool {
        guard TranscriptRewriteMode.parse(mode) == .smart else {
            return false
        }

        let durationMs = captureDurationMilliseconds()
        guard durationMs < Self.minimumSmartRewriteDurationMilliseconds else {
            return false
        }

        logger.log(
            "smart_rewrite_skipped reason=short_recording duration_ms=\(durationMs)" +
                " threshold_ms=\(Self.minimumSmartRewriteDurationMilliseconds)"
        )
        return true
    }

    private func shouldSkipSmartRewriteForLowNeed(mode: String, text: String) -> Bool {
        guard TranscriptRewriteMode.parse(mode) == .smart else {
            return false
        }

        let need = smartRewriteNeed(text: text)
        let reasonText = need.reasons.isEmpty ? "none" : need.reasons.joined(separator: ",")
        logger.log(
            "smart_rewrite_need score=\(need.score) threshold=\(Self.minimumSmartRewriteNeedScore) reasons=\(reasonText)"
        )

        guard need.score < Self.minimumSmartRewriteNeedScore else {
            return false
        }

        logger.log(
            "smart_rewrite_skipped reason=low_need score=\(need.score)" +
                " threshold=\(Self.minimumSmartRewriteNeedScore) reasons=\(reasonText)"
        )
        return true
    }

    private func smartRewriteNeed(text: String) -> (score: Int, reasons: [String]) {
        var score = 0
        var reasons: [String] = []

        let tokenCount = text.split(whereSeparator: \.isWhitespace).count
        let quality = captureQualityLabel()
        if quality != "ok" {
            score += 3
            reasons.append("capture_quality_\(quality)")
        }

        if text.count >= Self.longTranscriptCharacterThreshold {
            score += 1
            reasons.append("long_text_chars")
        }

        if tokenCount >= Self.longTranscriptTokenThreshold {
            score += 1
            reasons.append("long_text_tokens")
        }

        if tokenCount >= Self.runOnCandidateTokenThreshold && !hasInternalSentenceBoundary(text) {
            score += 1
            reasons.append("run_on_candidate")
        }

        return (score, reasons)
    }

    private func captureDurationMilliseconds() -> Int {
        max(0, Int((capturedDurationSeconds * 1000).rounded()))
    }

    private func hasInternalSentenceBoundary(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else {
            return false
        }

        let endIndex = trimmed.index(before: trimmed.endIndex)
        for index in trimmed.indices where index < endIndex {
            let character = trimmed[index]
            if character == "." || character == "!" || character == "?" {
                return true
            }
        }
        return false
    }

    private func frameDurationSeconds(_ frame: AudioFrame) -> Double {
        guard frame.sampleRate > 0 else {
            return 0
        }
        let channelCount = max(1, frame.channels)
        let samplesPerChannel = Double(frame.samples.count) / Double(channelCount)
        return samplesPerChannel / frame.sampleRate
    }

    private func captureQualityLabel() -> String {
        guard capturedFrameCount > 0 else {
            return "none"
        }

        switch capturedPeakRMS {
        case ..<0.01:
            return "very_low"
        case ..<0.03:
            return "low"
        default:
            return "ok"
        }
    }

    private func isErrorState(_ state: SessionState) -> Bool {
        if case .error = state {
            return true
        }
        return false
    }
}
