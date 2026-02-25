import Foundation

public final class GenericProcessASREngine: ASREngining, ASREngineErrorReporting, ASRWAVTranscribing, ASREngineLifecycle {
    public typealias CommandRunner = (_ executable: String, _ arguments: [String]) throws -> String
    public typealias WorkerFactory = (_ command: [String], _ model: String) -> PersistentASRWorking

    public enum EngineError: Error, Equatable {
        case invalidCommand
        case missingAudio
        case emptyTranscription
        case commandFailed(String)
    }

    public let providesFinalTranscriptOnStop = true

    private let command: [String]
    private let model: String
    private let runCommand: CommandRunner
    private let workerFactory: WorkerFactory
    private let fileManager: FileManager
    private var bufferedSamples: [Float] = []
    private var sampleRate: Int = 16_000
    private var worker: PersistentASRWorking?

    public private(set) var lastError: EngineError?
    public var lastEngineErrorDescription: String? {
        guard let lastError else {
            return nil
        }
        return String(describing: lastError)
    }

    public init(
        command: [String],
        model: String = "default",
        fileManager: FileManager = .default
    ) {
        self.command = command
        self.model = model
        self.runCommand = GenericProcessASREngine.defaultRunCommand
        self.workerFactory = { workerCommand, _ in
            PersistentASRWorker(command: workerCommand)
        }
        self.fileManager = fileManager
    }

    public init(
        command: [String],
        model: String = "default",
        runCommand: @escaping CommandRunner,
        workerFactory: WorkerFactory? = nil,
        fileManager: FileManager = .default
    ) {
        self.command = command
        self.model = model
        self.runCommand = runCommand
        self.workerFactory = workerFactory ?? { workerCommand, _ in
            PersistentASRWorker(command: workerCommand)
        }
        self.fileManager = fileManager
    }

    public func start() {
        bufferedSamples = []
        sampleRate = 16_000
        lastError = nil
    }

    public func consume(_ frame: AudioFrame) {
        if frame.sampleRate > 0 {
            sampleRate = Int(frame.sampleRate)
        }
        bufferedSamples.append(contentsOf: frame.samples)
    }

    public func stopAndFinalize() -> FinalTranscript? {
        guard !command.isEmpty else {
            lastError = .invalidCommand
            return nil
        }

        guard !bufferedSamples.isEmpty else {
            lastError = .missingAudio
            return nil
        }

        do {
            let wavURL = try writeTemporaryWAV(samples: bufferedSamples, sampleRate: sampleRate, channels: 1)
            defer { try? fileManager.removeItem(at: wavURL) }

            let output: String
            if usesPersistentWorker {
                output = try workerInstance().transcribe(wavPath: wavURL.path).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let executable = command[0]
                let arguments = Array(command.dropFirst()) + [wavURL.path, "--model", model]
                output = try runCommand(executable, arguments).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard !output.isEmpty else {
                lastError = .emptyTranscription
                return nil
            }

            return FinalTranscript(text: output, confidence: nil)
        } catch let error as EngineError {
            lastError = error
            return nil
        } catch {
            lastError = .commandFailed(Self.describe(error: error))
            return nil
        }
    }

    public func transcribeWAVFile(at path: String) -> FinalTranscript? {
        guard !command.isEmpty else {
            lastError = .invalidCommand
            return nil
        }

        do {
            let output: String
            if usesPersistentWorker {
                output = try workerInstance().transcribe(wavPath: path).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let executable = command[0]
                let arguments = Array(command.dropFirst()) + [path, "--model", model]
                output = try runCommand(executable, arguments).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !output.isEmpty else {
                lastError = .emptyTranscription
                return nil
            }
            return FinalTranscript(text: output, confidence: nil)
        } catch let error as EngineError {
            lastError = error
            return nil
        } catch {
            lastError = .commandFailed(Self.describe(error: error))
            return nil
        }
    }

    public func shutdown() {
        worker?.shutdown()
        worker = nil
    }

    private var usesPersistentWorker: Bool {
        command.contains("--server")
    }

    private func workerInstance() -> PersistentASRWorking {
        if let worker {
            return worker
        }
        let created = workerFactory(normalizedWorkerCommand(), model)
        worker = created
        return created
    }

    private func normalizedWorkerCommand() -> [String] {
        guard usesPersistentWorker else {
            return command
        }

        var normalized = command
        if !Self.commandHasModelArgument(normalized) {
            normalized.append(contentsOf: ["--model", model])
        }
        return normalized
    }

    private static func commandHasModelArgument(_ command: [String]) -> Bool {
        guard let modelIndex = command.firstIndex(of: "--model") else {
            return false
        }

        let valueIndex = command.index(after: modelIndex)
        guard valueIndex < command.endIndex else {
            return false
        }

        let modelValue = command[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return !modelValue.isEmpty && !modelValue.hasPrefix("--")
    }

    private static func describe(error: Error) -> String {
        if let description = (error as? LocalizedError)?.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty
        {
            return description
        }
        return String(describing: error)
    }

    private func writeTemporaryWAV(samples: [Float], sampleRate: Int, channels: Int) throws -> URL {
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent("asr-\(UUID().uuidString).wav")
        let data = try Self.makeWAVData(samples: samples, sampleRate: sampleRate, channels: channels)
        try data.write(to: fileURL)
        return fileURL
    }

    private static func makeWAVData(samples: [Float], sampleRate: Int, channels: Int) throws -> Data {
        guard channels > 0, sampleRate > 0 else {
            throw EngineError.commandFailed("invalid WAV format parameters")
        }

        let bitsPerSample = 16
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let pcmDataSize = samples.count * bitsPerSample / 8
        let riffChunkSize = 36 + pcmDataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(littleEndianUInt32(UInt32(riffChunkSize)))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(littleEndianUInt32(16))
        data.append(littleEndianUInt16(1))
        data.append(littleEndianUInt16(UInt16(channels)))
        data.append(littleEndianUInt32(UInt32(sampleRate)))
        data.append(littleEndianUInt32(UInt32(byteRate)))
        data.append(littleEndianUInt16(UInt16(blockAlign)))
        data.append(littleEndianUInt16(UInt16(bitsPerSample)))
        data.append("data".data(using: .ascii)!)
        data.append(littleEndianUInt32(UInt32(pcmDataSize)))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16((clamped * Float(Int16.max)).rounded())
            data.append(littleEndianInt16(intSample))
        }

        return data
    }

    private static func littleEndianUInt16(_ value: UInt16) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt16>.size)
    }

    private static func littleEndianUInt32(_ value: UInt32) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size)
    }

    private static func littleEndianInt16(_ value: Int16) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<Int16>.size)
    }

    private static func defaultRunCommand(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw EngineError.commandFailed("failed to launch command: \(error.localizedDescription)")
        }
        process.waitUntilExit()

        let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let stderrText = String(data: stderrData, encoding: .utf8) ?? "unknown error"
            throw EngineError.commandFailed(stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: stdoutData, encoding: .utf8) ?? ""
    }
}
