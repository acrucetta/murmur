import Foundation
import Testing
@testable import DictationAppCore

struct SessionOrchestratorTests {
    @Test
    func shortcutPressWithMissingPermissionsTransitionsToPermissionError() {
        let permissions = FakePermissionManager(
            snapshot: .init(
                microphone: .denied,
                accessibility: .authorized,
                inputMonitoring: .authorized
            )
        )
        let audio = FakeAudioCapture()
        let asr = FakeASREngine()
        let statusUI = StatusUISpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: permissions,
            audioCapture: audio,
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: statusUI,
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))

        #expect(orchestrator.state == .error(.permissionDenied))
        #expect(permissions.requestMissingPermissionsCallCount == 1)
        #expect(audio.startCallCount == 0)
        #expect(asr.startCallCount == 0)
        #expect(statusUI.lastPermissionPrompt != nil)
    }

    @Test
    func fullHappyPathInsertsCleanedTranscript() {
        let permissions = FakePermissionManager(snapshot: .allGranted)
        let audio = FakeAudioCapture()
        let asr = FakeASREngine()
        let writer = FakeFieldWriter()
        let history = TranscriptHistorySpy()
        let logger = LoggerSpy()
        let feedback = FeedbackSpy()
        let mediaController = RecordingMediaSpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: permissions,
            audioCapture: audio,
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            feedback: feedback,
            recordingMediaController: mediaController,
            transcriptHistory: history,
            logger: logger,
            now: ClockSequence([
                Date(timeIntervalSince1970: 1.201),
                Date(timeIntervalSince1970: 1.202),
                Date(timeIntervalSince1970: 1.203),
                Date(timeIntervalSince1970: 1.204),
                Date(timeIntervalSince1970: 1.205),
                Date(timeIntervalSince1970: 1.206),
                Date(timeIntervalSince1970: 1.207),
                Date(timeIntervalSince1970: 1.208),
                Date(timeIntervalSince1970: 1.209),
                Date(timeIntervalSince1970: 1.5),
                Date(timeIntervalSince1970: 1.8)
            ]).next
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date(timeIntervalSince1970: 1.0))))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date(timeIntervalSince1970: 1.2))))
        orchestrator.handle(.finalTranscript(.init(text: "   hello world   ", confidence: nil)))

        #expect(audio.startCallCount == 1)
        #expect(audio.stopCallCount == 1)
        #expect(asr.startCallCount == 1)
        #expect(asr.stopAndFinalizeCallCount == 1)
        #expect(asr.consumeCallCount == 0)
        #expect(writer.insertCallCount == 1)
        #expect(writer.lastInsertedText == "Hello world.")
        #expect(history.entries.count == 1)
        #expect(history.entries.first?.transcript == "Hello world.")
        #expect(history.entries.first?.insertResult.method == .accessibilityDirect)
        #expect(history.entries.first?.insertResult.success == true)
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("rewrite_input mode=\"literal\" chars=12 preview=\"Hello world.\"")
        }))
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("rewrite_output source=original changed=false chars=12 preview=\"Hello world.\"")
        }))
        #expect(logger.messages.contains(where: { $0.hasPrefix("insert_text chars=12 preview=\"Hello world.\"") }))
        #expect(logger.messages.contains("insert_result success=true method=accessibility_direct code=none"))
        #expect(logger.messages.contains("release_to_final_ms=300"))
        #expect(logger.messages.contains("release_to_insert_ms=600"))
        #expect(feedback.recordingStartCount == 1)
        #expect(feedback.recordingStopCount == 1)
        #expect(mediaController.pauseCallCount == 1)
        #expect(mediaController.resumeCallCount == 1)
        #expect(orchestrator.state == .idle)
    }

    @Test
    func shortcutPressLogsStartLatencyMilestones() {
        let logger = LoggerSpy()
        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: FakeASREngine(),
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            logger: logger,
            now: ClockSequence([
                Date(timeIntervalSince1970: 10.040),
                Date(timeIntervalSince1970: 10.041),
                Date(timeIntervalSince1970: 10.044),
                Date(timeIntervalSince1970: 10.045),
                Date(timeIntervalSince1970: 10.052),
                Date(timeIntervalSince1970: 10.065),
                Date(timeIntervalSince1970: 10.066),
                Date(timeIntervalSince1970: 10.068),
                Date(timeIntervalSince1970: 10.090)
            ]).next
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date(timeIntervalSince1970: 10.0))))

        #expect(logger.messages.contains("shortcut_to_listening_ms=40"))
        #expect(logger.messages.contains("asr_start_duration_ms=3"))
        #expect(logger.messages.contains("audio_capture_start_duration_ms=7"))
        #expect(logger.messages.contains("shortcut_to_audio_start_ms=65"))
        #expect(logger.messages.contains("feedback_dispatch_duration_ms=2"))
        #expect(logger.messages.contains("shortcut_to_feedback_dispatch_ms=90"))
    }

    @Test
    func firstAudioFrameLatencyLogsOnlyOncePerSession() {
        let logger = LoggerSpy()
        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: FakeASREngine(),
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            logger: logger,
            now: ClockSequence([
                Date(timeIntervalSince1970: 20.005),
                Date(timeIntervalSince1970: 20.006),
                Date(timeIntervalSince1970: 20.007),
                Date(timeIntervalSince1970: 20.008),
                Date(timeIntervalSince1970: 20.009),
                Date(timeIntervalSince1970: 20.010),
                Date(timeIntervalSince1970: 20.020),
                Date(timeIntervalSince1970: 20.030),
                Date(timeIntervalSince1970: 20.040),
                Date(timeIntervalSince1970: 20.155)
            ]).next
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date(timeIntervalSince1970: 20.0))))
        orchestrator.handle(.audioFrame(.init(samples: [0.1, 0.2], sampleRate: 16_000, channels: 1)))
        orchestrator.handle(.audioFrame(.init(samples: [0.2, 0.1], sampleRate: 16_000, channels: 1)))

        #expect(logger.messages.contains("shortcut_to_first_audio_frame_ms=155"))
        #expect(logger.messages.filter { $0 == "shortcut_to_first_audio_frame_ms=155" }.count == 1)
    }

    @Test
    func shortcutReleaseCanFinalizeImmediatelyFromASREngine() {
        let asr = FakeASREngine()
        asr.nextFinalTranscript = .init(text: "quick transcript", confidence: 0.82)
        let writer = FakeFieldWriter()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(asr.stopAndFinalizeCallCount == 1)
        #expect(writer.insertCallCount == 1)
        #expect(writer.lastInsertedText == "Quick transcript.")
        #expect(orchestrator.state == .idle)
    }

    @Test
    func synchronousASRFailureMovesToEngineError() {
        let asr = FakeASREngine()
        asr.providesFinalTranscriptOnStopValue = true
        let statusUI = StatusUISpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: statusUI,
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(orchestrator.state == .error(.engineError))
        #expect(statusUI.lastError == .engineError)
    }

    @Test
    func moonshineFailureLogsConcreteReason() {
        let asr = MoonshineProcessASREngine(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            runCommand: { _, _ in "unused" }
        )
        let logger = LoggerSpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            logger: logger
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(logger.messages.contains(where: {
            $0.contains("engine finalize failed: no transcript produced reason=missingAudio") &&
                $0.contains("captured_frames=0") &&
                $0.contains("captured_quality=none")
        }))
        #expect(orchestrator.state == .error(.engineError))
    }

    @Test
    func moonshineFailureLogsCaptureDiagnosticsWhenAudioWasCaptured() {
        let asr = MoonshineProcessASREngine(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            runCommand: { _, _ in throw MoonshineProcessASREngine.EngineError.commandFailed("onnx: empty transcription") }
        )
        let logger = LoggerSpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            logger: logger
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.audioFrame(.init(samples: [0.5, -0.5], sampleRate: 16_000, channels: 1)))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(logger.messages.contains(where: {
            $0.contains("reason=commandFailed(\"onnx: empty transcription\")") &&
                $0.contains("captured_frames=1") &&
                $0.contains("captured_samples=2") &&
                $0.contains("captured_peak_rms=0.50000") &&
                $0.contains("captured_quality=ok")
        }))
        #expect(orchestrator.state == .error(.engineError))
    }

    @Test
    func pressAfterEngineErrorRecoversToListening() {
        let asr = FakeASREngine()
        asr.providesFinalTranscriptOnStopValue = true
        let audio = FakeAudioCapture()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: audio,
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))
        #expect(orchestrator.state == .error(.engineError))

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        #expect(orchestrator.state == .listening)
        #expect(audio.startCallCount == 2)
        #expect(asr.startCallCount == 2)
    }

    @Test
    func moonshineBackendFinalizationFlowsToInsertion() {
        let asr = MoonshineProcessASREngine(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            runCommand: { _, _ in "moonshine live final" }
        )
        let writer = FakeFieldWriter()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.audioFrame(.init(samples: [0.02, 0.01], sampleRate: 16_000, channels: 1)))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(writer.insertCallCount == 1)
        #expect(writer.lastInsertedText == "Moonshine live final.")
        #expect(orchestrator.state == .idle)
    }

    @Test
    func synchronousAudioFrameDuringStartIsRetainedForFinalization() {
        let audio = FakeAudioCapture()
        let asr = MoonshineProcessASREngine(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            runCommand: { _, _ in "live transcript" }
        )
        let writer = FakeFieldWriter()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: audio,
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: NoopLogger()
        )

        audio.onStart = {
            orchestrator.handle(.audioFrame(.init(samples: [0.09, 0.02, -0.01], sampleRate: 16_000, channels: 1)))
        }

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(writer.insertCallCount == 1)
        #expect(writer.lastInsertedText == "Live transcript.")
        #expect(orchestrator.state == .idle)
    }

    @Test
    func duplicateShortcutPressWhileListeningDoesNotResetASREngineBuffer() {
        let audio = FakeAudioCapture()
        let asr = MoonshineProcessASREngine(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            runCommand: { _, _ in "duplicate press stable" }
        )
        let writer = FakeFieldWriter()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: audio,
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: NoopLogger()
        )

        audio.onStart = {
            orchestrator.handle(.audioFrame(.init(samples: [0.03, 0.07, 0.01], sampleRate: 16_000, channels: 1)))
        }

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutPressed(.init(timestamp: Date().addingTimeInterval(0.05))))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date().addingTimeInterval(0.10))))

        #expect(audio.startCallCount == 1)
        #expect(writer.insertCallCount == 1)
        #expect(writer.lastInsertedText == "Duplicate press stable.")
        #expect(orchestrator.state == .idle)
    }

    @Test
    func partialTranscriptUpdatesStatusUI() {
        let statusUI = StatusUISpy()
        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: FakeASREngine(),
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: statusUI,
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.partialTranscript(.init(text: "hello", confidence: nil)))

        #expect(statusUI.partialTranscripts == ["hello"])
        #expect(orchestrator.state == .listening)
    }

    @Test
    func audioFramesForwardedOnlyWhileListening() {
        let asr = FakeASREngine()
        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            logger: NoopLogger()
        )

        let frame = AudioFrame(samples: [0.1, 0.2], sampleRate: 16_000, channels: 1)

        orchestrator.handle(.audioFrame(frame))
        #expect(asr.consumeCallCount == 0)

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.audioFrame(frame))
        #expect(asr.consumeCallCount == 1)
    }

    @Test
    func recordingFeedbackFiresOnPressAndRelease() {
        let asr = FakeASREngine()
        asr.nextFinalTranscript = .init(text: "hello", confidence: 0.9)
        let feedback = FeedbackSpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            feedback: feedback,
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(feedback.recordingStartCount == 1)
        #expect(feedback.recordingStopCount == 1)
    }

    @Test
    func recordingFeedbackDoesNotFireWhenPermissionsDenied() {
        let feedback = FeedbackSpy()
        let mediaController = RecordingMediaSpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(
                snapshot: .init(
                    microphone: .denied,
                    accessibility: .authorized,
                    inputMonitoring: .authorized
                )
            ),
            audioCapture: FakeAudioCapture(),
            asrEngine: FakeASREngine(),
            postProcessor: TextPostProcessorV2(),
            fieldWriter: FakeFieldWriter(),
            statusUI: StatusUISpy(),
            feedback: feedback,
            recordingMediaController: mediaController,
            logger: NoopLogger()
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))

        #expect(feedback.recordingStartCount == 0)
        #expect(feedback.recordingStopCount == 0)
        #expect(mediaController.pauseCallCount == 0)
        #expect(mediaController.resumeCallCount == 0)
    }

    @Test
    func appliesSmartRewriteWithProvidedContextBeforeInsert() {
        let asr = FakeASREngine()
        asr.nextFinalTranscript = .init(
            text: "ship tomorrow maybe next week but not sure maybe follow up with the team and confirm the final timeline before sending and also check with finance and legal before we announce the date to everyone in the company channel",
            confidence: 0.8
        )
        let writer = FakeFieldWriter()
        let rewriter = RewriteSpy(nextResult: "Ship tomorrow. Maybe next week, but let's confirm the timeline before sending.")
        let logger = LoggerSpy()
        let contextProvider = FixedRewriteContextProvider(
            context: .init(
                frontmostAppBundleID: "com.apple.mail",
                frontmostAppName: "Mail",
                mode: "smart"
            )
        )

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(mode: .literal),
            transcriptRewriter: rewriter,
            rewriteContextProvider: contextProvider,
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: logger
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.audioFrame(.init(samples: Array(repeating: 0.005, count: 8_000), sampleRate: 16_000, channels: 1)))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(rewriter.callCount == 1)
        #expect(rewriter.lastInput?.contains("confirm the final timeline before sending") == true)
        #expect(rewriter.lastContext?.frontmostAppBundleID == "com.apple.mail")
        #expect(rewriter.lastContext?.mode == "smart")
        #expect(writer.lastInsertedText == "Ship tomorrow. Maybe next week, but let's confirm the timeline before sending.")
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("rewrite_input mode=\"smart\"")
        }))
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("rewrite_output source=llm changed=true")
        }))
    }

    @Test
    func smartRewriteSkipsVeryShortRecordingAndKeepsDeterministicText() {
        let asr = FakeASREngine()
        asr.nextFinalTranscript = .init(text: "ship tomorrow", confidence: 0.8)
        let writer = FakeFieldWriter()
        let rewriter = RewriteSpy(nextResult: "Ship on Friday.")
        let logger = LoggerSpy()
        let contextProvider = FixedRewriteContextProvider(
            context: .init(
                frontmostAppBundleID: "com.apple.mail",
                frontmostAppName: "Mail",
                mode: "smart"
            )
        )

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(mode: .literal),
            transcriptRewriter: rewriter,
            rewriteContextProvider: contextProvider,
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: logger
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.audioFrame(.init(samples: Array(repeating: 0.05, count: 400), sampleRate: 16_000, channels: 1)))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(rewriter.callCount == 0)
        #expect(writer.lastInsertedText == "Ship tomorrow.")
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("smart_rewrite_skipped reason=short_recording duration_ms=")
        }))
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("rewrite_output source=original changed=false chars=14 preview=\"Ship tomorrow.\"")
        }))
    }

    @Test
    func smartRewriteSkipsLowNeedHighQualityTranscript() {
        let asr = FakeASREngine()
        asr.nextFinalTranscript = .init(text: "this is already easy to read and should stay local", confidence: 0.9)
        let writer = FakeFieldWriter()
        let rewriter = RewriteSpy(nextResult: "This rewrite should not run.")
        let logger = LoggerSpy()
        let contextProvider = FixedRewriteContextProvider(
            context: .init(
                frontmostAppBundleID: "com.apple.mail",
                frontmostAppName: "Mail",
                mode: "smart"
            )
        )

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(mode: .literal),
            transcriptRewriter: rewriter,
            rewriteContextProvider: contextProvider,
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: logger
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.audioFrame(.init(samples: Array(repeating: 0.08, count: 8_000), sampleRate: 16_000, channels: 1)))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(rewriter.callCount == 0)
        #expect(writer.lastInsertedText == "This is already easy to read and should stay local.")
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("smart_rewrite_need score=")
        }))
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("smart_rewrite_skipped reason=low_need")
        }))
    }

    @Test
    func smartRewriteDoesNotSkipLowNeedWhenCaptureQualityIsLow() {
        let asr = FakeASREngine()
        asr.nextFinalTranscript = .init(text: "this is already easy to read and should stay local", confidence: 0.9)
        let writer = FakeFieldWriter()
        let rewriter = RewriteSpy(nextResult: "This rewrite should run.")
        let logger = LoggerSpy()
        let contextProvider = FixedRewriteContextProvider(
            context: .init(
                frontmostAppBundleID: "com.apple.mail",
                frontmostAppName: "Mail",
                mode: "smart"
            )
        )

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(mode: .literal),
            transcriptRewriter: rewriter,
            rewriteContextProvider: contextProvider,
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: logger
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.audioFrame(.init(samples: Array(repeating: 0.005, count: 8_000), sampleRate: 16_000, channels: 1)))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(rewriter.callCount == 1)
        #expect(writer.lastInsertedText == "This rewrite should run.")
        #expect(logger.messages.contains(where: {
            $0.contains("smart_rewrite_need score=") && $0.contains("capture_quality_very_low")
        }))
        #expect(logger.messages.contains(where: {
            $0.hasPrefix("smart_rewrite_skipped reason=low_need")
        }) == false)
    }

    @Test
    func insertionFailureIsLoggedWithMethodAndCode() {
        let asr = FakeASREngine()
        asr.nextFinalTranscript = .init(text: "hello", confidence: 0.9)
        let writer = FakeFieldWriter()
        writer.nextResult = .init(success: false, method: .clipboardPaste, error: .insertionFailed)
        let logger = LoggerSpy()

        let orchestrator = SessionOrchestrator(
            permissionManager: FakePermissionManager(snapshot: .allGranted),
            audioCapture: FakeAudioCapture(),
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            logger: logger
        )

        orchestrator.handle(.shortcutPressed(.init(timestamp: Date())))
        orchestrator.handle(.shortcutReleased(.init(timestamp: Date())))

        #expect(logger.messages.contains("insert_result success=false method=clipboard_paste code=insertion_failed"))
    }
}

private final class FakePermissionManager: PermissionManaging {
    var snapshot: PermissionSnapshot
    var requestMissingPermissionsCallCount = 0

    init(snapshot: PermissionSnapshot) {
        self.snapshot = snapshot
    }

    func currentStatus() -> PermissionSnapshot {
        snapshot
    }

    func requestMissingPermissions() {
        requestMissingPermissionsCallCount += 1
    }
}

private final class FakeAudioCapture: AudioCapturing {
    var startCallCount = 0
    var stopCallCount = 0
    var onStart: (() -> Void)?

    func start() {
        startCallCount += 1
        onStart?()
    }

    func stop() {
        stopCallCount += 1
    }
}

private final class FakeASREngine: ASREngining {
    var startCallCount = 0
    var stopAndFinalizeCallCount = 0
    var consumeCallCount = 0
    var nextFinalTranscript: FinalTranscript?
    var providesFinalTranscriptOnStopValue = false

    var providesFinalTranscriptOnStop: Bool {
        providesFinalTranscriptOnStopValue
    }

    func start() {
        startCallCount += 1
    }

    func consume(_ frame: AudioFrame) {
        consumeCallCount += 1
    }

    func stopAndFinalize() -> FinalTranscript? {
        stopAndFinalizeCallCount += 1
        return nextFinalTranscript
    }
}

private final class FakeFieldWriter: FocusedFieldWriting {
    var insertCallCount = 0
    var lastInsertedText: String?
    var nextResult: InsertResult = .init(success: true, method: .accessibilityDirect, error: nil)

    func insert(_ text: String) -> InsertResult {
        insertCallCount += 1
        lastInsertedText = text
        return nextResult
    }
}

private final class LoggerSpy: Logging {
    private(set) var messages: [String] = []

    func log(_ message: String) {
        messages.append(message)
    }
}

private final class TranscriptHistorySpy: TranscriptHistoryWriting {
    private(set) var entries: [TranscriptHistoryEntry] = []

    func record(_ entry: TranscriptHistoryEntry) {
        entries.append(entry)
    }
}

private final class ClockSequence {
    private var values: [Date]
    private let fallback: Date

    init(_ values: [Date], fallback: Date = Date(timeIntervalSince1970: 0)) {
        self.values = values
        self.fallback = fallback
    }

    func next() -> Date {
        guard !values.isEmpty else {
            return fallback
        }
        return values.removeFirst()
    }
}

private final class RewriteSpy: TranscriptRewriting {
    var callCount = 0
    var lastInput: String?
    var lastContext: RewriteContext?
    var nextResult: String?

    init(nextResult: String?) {
        self.nextResult = nextResult
    }

    func rewrite(_ text: String, context: RewriteContext) -> String? {
        callCount += 1
        lastInput = text
        lastContext = context
        return nextResult
    }
}

private struct FixedRewriteContextProvider: RewriteContextProviding {
    let context: RewriteContext

    func currentContext() -> RewriteContext {
        context
    }
}
