import Foundation
#if canImport(Darwin)
import Darwin
#endif

public protocol PersistentASRWorking: AnyObject {
    func transcribe(wavPath: String) throws -> String
    func shutdown()
}

protocol PersistentASRProcessSession: AnyObject {
    var isRunning: Bool { get }
    var terminationStatus: Int32 { get }
    var onUnexpectedExit: ((Int32) -> Void)? { get set }
    func start() throws
    func sendLine(_ line: String) throws
    func nextLine(timeout: TimeInterval) throws -> String?
    func closeInput()
    func terminate()
    func kill()
    func waitForExit(timeout: TimeInterval) -> Bool
}

public final class PersistentASRWorker: PersistentASRWorking {
    enum WorkerError: Error, Equatable, CustomStringConvertible, LocalizedError {
        case invalidCommand
        case readyTimeout
        case protocolViolation(String)
        case requestFailed(String)
        case processExited(String)
        case ioError(String)
        case resultTimeout

        var description: String {
            switch self {
            case .invalidCommand:
                return "invalidCommand"
            case .readyTimeout:
                return "readyTimeout"
            case .protocolViolation(let detail):
                return "protocolViolation(\(detail))"
            case .requestFailed(let detail):
                return "requestFailed(\(detail))"
            case .processExited(let detail):
                return "processExited(\(detail))"
            case .ioError(let detail):
                return "ioError(\(detail))"
            case .resultTimeout:
                return "resultTimeout"
            }
        }

        var errorDescription: String? {
            description
        }
    }

    private struct RequestMessage: Codable {
        let type: String
        let id: String?
        let wavPath: String?

        enum CodingKeys: String, CodingKey {
            case type
            case id
            case wavPath = "wav_path"
        }
    }

    private struct ResponseMessage: Codable {
        let type: String
        let id: String?
        let ok: Bool?
        let text: String?
        let error: String?
        let model: String?
        let pid: Int32?
    }

    typealias SessionFactory = (_ command: [String], _ logger: Logging) -> PersistentASRProcessSession

    private let command: [String]
    private let logger: Logging
    private let readyTimeout: TimeInterval
    private let resultTimeout: TimeInterval
    private let sessionFactory: SessionFactory
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private var session: PersistentASRProcessSession?

    public init(
        command: [String],
        logger: Logging = NoopLogger(),
        readyTimeout: TimeInterval = 60,
        resultTimeout: TimeInterval = 120
    ) {
        self.command = command
        self.logger = logger
        self.readyTimeout = readyTimeout
        self.resultTimeout = resultTimeout
        self.sessionFactory = { launchCommand, launchLogger in
            LineBufferedNDJSONProcessSession(command: launchCommand, logger: launchLogger)
        }
    }

    init(
        command: [String],
        logger: Logging = NoopLogger(),
        readyTimeout: TimeInterval = 60,
        resultTimeout: TimeInterval = 120,
        sessionFactory: @escaping SessionFactory
    ) {
        self.command = command
        self.logger = logger
        self.readyTimeout = readyTimeout
        self.resultTimeout = resultTimeout
        self.sessionFactory = sessionFactory
    }

    deinit {
        shutdown()
    }

    func ensureRunning() throws {
        if let current = lock.withLock({ session }), current.isRunning {
            return
        }

        guard !command.isEmpty else {
            throw WorkerError.invalidCommand
        }

        let newSession = sessionFactory(command, logger)
        newSession.onUnexpectedExit = { [logger] status in
            logger.log("persistent_asr_worker_exit status=\(status)")
        }
        do {
            try newSession.start()
        } catch {
            throw WorkerError.ioError("failed to start ASR worker: \(error.localizedDescription)")
        }

        guard let line = try newSession.nextLine(timeout: readyTimeout) else {
            throw WorkerError.readyTimeout
        }
        let response = try decodeResponse(line)
        guard response.type == "ready" else {
            throw WorkerError.protocolViolation("expected ready message, got \(response.type)")
        }

        lock.withLock { session = newSession }
    }

    public func transcribe(wavPath: String) throws -> String {
        var attempts = 0
        while true {
            do {
                return try transcribeOnce(wavPath: wavPath)
            } catch let error as WorkerError {
                if attempts == 0, case .processExited = error {
                    restartWorker()
                    attempts += 1
                    continue
                }
                if attempts == 0, case .ioError = error {
                    restartWorker()
                    attempts += 1
                    continue
                }
                throw error
            }
        }
    }

    public func shutdown() {
        let current = lock.withLock { () -> PersistentASRProcessSession? in
            defer { session = nil }
            return session
        }
        guard let current else {
            return
        }

        do {
            let payload = RequestMessage(type: "shutdown", id: nil, wavPath: nil)
            let line = try encodeRequest(payload)
            try current.sendLine(line)
        } catch {
            logger.log("persistent_asr_worker_shutdown_send_failed error=\"\(error.localizedDescription)\"")
        }
        current.closeInput()
        if !current.waitForExit(timeout: 5) {
            current.terminate()
        }
        if !current.waitForExit(timeout: 2) {
            current.kill()
        }
        _ = current.waitForExit(timeout: 1)
    }

    private func transcribeOnce(wavPath: String) throws -> String {
        try ensureRunning()
        guard let current = lock.withLock({ session }) else {
            throw WorkerError.processExited("worker process not available")
        }

        let requestID = UUID().uuidString
        let request = RequestMessage(type: "transcribe", id: requestID, wavPath: wavPath)
        let line = try encodeRequest(request)

        do {
            try current.sendLine(line)
        } catch {
            throw WorkerError.ioError("failed to write request: \(error.localizedDescription)")
        }

        let deadline = Date().addingTimeInterval(resultTimeout)
        while Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            guard let responseLine = try current.nextLine(timeout: max(0.05, remaining)) else {
                if !current.isRunning {
                    throw WorkerError.processExited("worker process exited with status \(current.terminationStatus)")
                }
                continue
            }

            let response = try decodeResponse(responseLine)
            if response.type == "ready" {
                continue
            }
            guard response.type == "result" else {
                throw WorkerError.protocolViolation("unexpected response type \(response.type)")
            }
            guard response.id == requestID else {
                continue
            }
            guard response.ok == true else {
                throw WorkerError.requestFailed(response.error ?? "unknown worker failure")
            }
            let text = (response.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw WorkerError.requestFailed("empty transcription")
            }
            return text
        }

        throw WorkerError.resultTimeout
    }

    private func restartWorker() {
        shutdown()
    }

    private func encodeRequest(_ request: RequestMessage) throws -> String {
        let data = try encoder.encode(request)
        guard let line = String(data: data, encoding: .utf8) else {
            throw WorkerError.ioError("failed to encode request payload")
        }
        return line
    }

    private func decodeResponse(_ line: String) throws -> ResponseMessage {
        guard let data = line.data(using: .utf8) else {
            throw WorkerError.protocolViolation("invalid utf8 response")
        }
        do {
            return try decoder.decode(ResponseMessage.self, from: data)
        } catch {
            throw WorkerError.protocolViolation("invalid json response: \(line)")
        }
    }
}

private final class LineBufferedNDJSONProcessSession: PersistentASRProcessSession, @unchecked Sendable {
    var onUnexpectedExit: ((Int32) -> Void)?
    var isRunning: Bool { process?.isRunning ?? false }
    var terminationStatus: Int32 { process?.terminationStatus ?? -1 }

    private let command: [String]
    private let logger: Logging
    private let lock = NSLock()
    private let lineSemaphore = DispatchSemaphore(value: 0)

    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var outputBuffer = Data()
    private var errorBuffer = Data()
    private var lineQueue: [String] = []
    private var intentionalShutdown = false

    init(command: [String], logger: Logging) {
        self.command = command
        self.logger = logger
    }

    func start() throws {
        guard !command.isEmpty else {
            throw PersistentASRWorker.WorkerError.invalidCommand
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        process.terminationHandler = { [weak self] proc in
            guard let self else { return }
            self.lock.withLock {
                self.outputHandle?.readabilityHandler = nil
                self.errorHandle?.readabilityHandler = nil
            }
            if !self.intentionalShutdown {
                self.onUnexpectedExit?(proc.terminationStatus)
            }
            self.lineSemaphore.signal()
        }

        outputHandle = stdoutPipe.fileHandleForReading
        errorHandle = stderrPipe.fileHandleForReading
        inputHandle = stdinPipe.fileHandleForWriting

        outputHandle?.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            self.handleReadableData(data, isError: false)
        }
        errorHandle?.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            self.handleReadableData(data, isError: true)
        }

        self.process = process
        try process.run()
    }

    func sendLine(_ line: String) throws {
        guard let handle = inputHandle else {
            throw PersistentASRWorker.WorkerError.ioError("stdin unavailable")
        }
        guard let data = (line + "\n").data(using: .utf8) else {
            throw PersistentASRWorker.WorkerError.ioError("failed to encode request")
        }
        try handle.write(contentsOf: data)
    }

    func nextLine(timeout: TimeInterval) throws -> String? {
        let waitResult = lineSemaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            return nil
        }
        return lock.withLock {
            if lineQueue.isEmpty {
                return nil
            }
            return lineQueue.removeFirst()
        }
    }

    func closeInput() {
        intentionalShutdown = true
        try? inputHandle?.close()
    }

    func terminate() {
        intentionalShutdown = true
        process?.terminate()
    }

    func kill() {
        intentionalShutdown = true
        guard let pid = process?.processIdentifier else { return }
        #if canImport(Darwin)
        _ = Darwin.kill(pid_t(pid), SIGKILL)
        #endif
    }

    func waitForExit(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !(process?.isRunning ?? false) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return !(process?.isRunning ?? false)
    }

    private func handleReadableData(_ data: Data, isError: Bool) {
        lock.withLock {
            if data.isEmpty {
                return
            }
            if isError {
                errorBuffer.append(data)
                drainBuffer(isError: true)
            } else {
                outputBuffer.append(data)
                drainBuffer(isError: false)
            }
        }
    }

    private func drainBuffer(isError: Bool) {
        if isError {
            while let line = extractLine(from: &errorBuffer) {
                logger.log("persistent_asr_worker_stderr message=\"\(line)\"")
            }
            return
        }

        while let line = extractLine(from: &outputBuffer) {
            lineQueue.append(line)
            lineSemaphore.signal()
        }
    }

    private func extractLine(from buffer: inout Data) -> String? {
        guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
            return nil
        }
        let lineData = buffer[..<newlineIndex]
        buffer.removeSubrange(...newlineIndex)
        return String(decoding: lineData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try operation()
    }
}
