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

        let orchestrator = SessionOrchestrator(
            permissionManager: permissions,
            audioCapture: audio,
            asrEngine: asr,
            postProcessor: TextPostProcessorV2(),
            fieldWriter: writer,
            statusUI: StatusUISpy(),
            transcriptHistory: history,
            logger: logger,
            now: ClockSequence([
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
        #expect(logger.messages.contains("release_to_final_ms=300"))
        #expect(logger.messages.contains("release_to_insert_ms=600"))
        #expect(orchestrator.state == .idle)
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

    func start() {
        startCallCount += 1
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
