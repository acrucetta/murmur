import Foundation

public final class SessionOrchestrator {
    public typealias NowProvider = () -> Date

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
    private var releaseTimestamp: Date?
    private var capturedFrameCount = 0
    private var capturedSampleCount = 0
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
                let rewritten = transcriptRewriter
                    .rewrite(cleaned, context: rewriteContext)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
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
            recordingMediaController.pauseMediaForRecording()
            resetCaptureDiagnostics()
            asrEngine.start()
            audioCapture.start()
            feedback.recordingDidStart()
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
        capturedRMSAccumulator = 0
        capturedPeakRMS = 0
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
