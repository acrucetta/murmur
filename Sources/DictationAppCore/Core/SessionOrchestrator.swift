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
    private let transcriptHistory: TranscriptHistoryWriting
    private let logger: Logging
    private let now: NowProvider
    private var releaseTimestamp: Date?

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
            context: .init(frontmostAppBundleID: nil, frontmostAppName: nil, mode: TranscriptRewriteMode.smart.rawValue)
        ),
        fieldWriter: FocusedFieldWriting,
        statusUI: StatusPresenting,
        feedback: FeedbackPresenting = NoopFeedbackPresenter(),
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
                releaseTimestamp = releaseDate(from: event)
                audioCapture.stop()
                let finalTranscript = asrEngine.stopAndFinalize()
                if let finalTranscript {
                    handle(.finalTranscript(finalTranscript))
                } else if asrEngine.providesFinalTranscriptOnStop {
                    statusUI.showError(.engineError)
                    state = .error(.engineError)
                    logger.log("engine finalize failed: no transcript produced")
                }
            }
        case .audioFrame(let audioFrame):
            guard state == .listening else {
                return
            }
            asrEngine.consume(audioFrame)
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
                let rewritten = transcriptRewriter
                    .rewrite(cleaned, context: rewriteContext)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let textToInsert = rewritten.flatMap { $0.isEmpty ? nil : $0 } ?? cleaned
                let insertResult = fieldWriter.insert(textToInsert)
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
            audioCapture.start()
            asrEngine.start()
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

    private func isErrorState(_ state: SessionState) -> Bool {
        if case .error = state {
            return true
        }
        return false
    }
}
