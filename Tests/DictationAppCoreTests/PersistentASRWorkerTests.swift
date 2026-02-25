import Foundation
import Testing
@testable import DictationAppCore

struct PersistentASRWorkerTests {
    final class FakeSession: PersistentASRProcessSession {
        var isRunning = true
        var terminationStatus: Int32 = 0
        var onUnexpectedExit: ((Int32) -> Void)?

        var startError: Error?
        var sendError: Error?
        var sentLines: [String] = []
        var queuedLines: [String]
        var closeInputCallCount = 0
        var terminateCallCount = 0
        var killCallCount = 0
        var waitForExitResponses: [Bool] = [true]
        var onSendLine: ((String) -> Void)?

        init(queuedLines: [String]) {
            self.queuedLines = queuedLines
        }

        func start() throws {
            if let startError {
                throw startError
            }
        }

        func sendLine(_ line: String) throws {
            if let sendError {
                throw sendError
            }
            sentLines.append(line)
            onSendLine?(line)
        }

        func nextLine(timeout _: TimeInterval) throws -> String? {
            guard !queuedLines.isEmpty else {
                return nil
            }
            return queuedLines.removeFirst()
        }

        func closeInput() {
            closeInputCallCount += 1
        }

        func terminate() {
            terminateCallCount += 1
        }

        func kill() {
            killCallCount += 1
        }

        func waitForExit(timeout _: TimeInterval) -> Bool {
            if waitForExitResponses.isEmpty {
                return true
            }
            return waitForExitResponses.removeFirst()
        }
    }

    @Test
    func readyHandshakeTimesOutWhenNoReadyMessageArrives() {
        let session = FakeSession(queuedLines: [])
        let worker = PersistentASRWorker(
            command: ["python3", "scripts/hf_asr_transcribe.py", "--server"],
            readyTimeout: 0.01,
            sessionFactory: { _, _ in session }
        )

        #expect(throws: PersistentASRWorker.WorkerError.readyTimeout) {
            try worker.ensureRunning()
        }
    }

    @Test
    func transcribeRoundTripReturnsWorkerText() throws {
        let session = FakeSession(queuedLines: [
            #"{"type":"ready","model":"mlx-community/Qwen3-ASR-0.6B-4bit","pid":100}"#
        ])
        session.onSendLine = { line in
            guard line.contains(#""type":"transcribe""#) else { return }
            guard let data = line.data(using: .utf8),
                  let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let requestID = request["id"] as? String
            else {
                return
            }
            session.queuedLines.append(
                #"{"type":"result","id":"\#(requestID)","ok":true,"text":"hello world"}"#
            )
        }

        let worker = PersistentASRWorker(
            command: ["python3", "scripts/hf_asr_transcribe.py", "--server"],
            sessionFactory: { _, _ in session }
        )

        let text = try worker.transcribe(wavPath: "/tmp/a.wav")
        #expect(text == "hello world")
    }

    @Test
    func restartsOnceWhenWorkerExitsMidRequest() throws {
        let crashing = FakeSession(queuedLines: [
            #"{"type":"ready","model":"mlx-community/Qwen3-ASR-0.6B-4bit","pid":100}"#
        ])
        crashing.waitForExitResponses = [true]
        crashing.onSendLine = { line in
            guard line.contains(#""type":"transcribe""#) else { return }
            crashing.isRunning = false
            crashing.terminationStatus = 9
            crashing.onUnexpectedExit?(9)
        }

        let healthy = FakeSession(queuedLines: [
            #"{"type":"ready","model":"mlx-community/Qwen3-ASR-0.6B-4bit","pid":101}"#
        ])
        healthy.onSendLine = { line in
            guard line.contains(#""type":"transcribe""#) else { return }
            guard let data = line.data(using: .utf8),
                  let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let requestID = request["id"] as? String
            else {
                return
            }
            healthy.queuedLines.append(
                #"{"type":"result","id":"\#(requestID)","ok":true,"text":"retry success"}"#
            )
        }

        var factoryCalls = 0
        let worker = PersistentASRWorker(
            command: ["python3", "scripts/hf_asr_transcribe.py", "--server"],
            sessionFactory: { _, _ in
                factoryCalls += 1
                return factoryCalls == 1 ? crashing : healthy
            }
        )

        let text = try worker.transcribe(wavPath: "/tmp/b.wav")
        #expect(text == "retry success")
        #expect(factoryCalls == 2)
    }

    @Test
    func shutdownSendsCommandAndEscalatesTerminateToKill() throws {
        let session = FakeSession(queuedLines: [
            #"{"type":"ready","model":"mlx-community/Qwen3-ASR-0.6B-4bit","pid":100}"#
        ])
        session.waitForExitResponses = [false, false, true]
        let worker = PersistentASRWorker(
            command: ["python3", "scripts/hf_asr_transcribe.py", "--server"],
            sessionFactory: { _, _ in session }
        )

        try worker.ensureRunning()
        worker.shutdown()

        #expect(session.sentLines.contains { $0.contains(#""type":"shutdown""#) })
        #expect(session.closeInputCallCount == 1)
        #expect(session.terminateCallCount == 1)
        #expect(session.killCallCount == 1)
    }
}
