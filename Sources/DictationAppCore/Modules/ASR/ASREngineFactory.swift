import Foundation

public enum ASREngineFactory {
    enum RuntimeKind: String {
        case moonshine
        case generic
    }

    public static func makeProcessEngine(
        command: [String],
        model: String,
        offline: Bool = true,
        modelProvider: GenericProcessASREngine.ModelProvider? = nil,
        fileManager: FileManager = .default
    ) -> ASREngining {
        switch inferRuntime(command: command, model: model) {
        case .moonshine:
            return MoonshineProcessASREngine(
                command: command,
                model: model,
                offline: offline,
                fileManager: fileManager
            )
        case .generic:
            let configuredCommand = configuredGenericCommand(command: command)
            return GenericProcessASREngine(
                command: configuredCommand,
                model: model,
                modelProvider: modelProvider,
                fileManager: fileManager
            )
        }
    }

    static func inferRuntime(command: [String], model: String) -> RuntimeKind {
        if commandMentionsMoonshine(command) || modelMentionsMoonshine(model) {
            return .moonshine
        }
        return .generic
    }

    private static func commandMentionsMoonshine(_ command: [String]) -> Bool {
        command.contains { component in
            component
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .contains("moonshine")
        }
    }

    private static func modelMentionsMoonshine(_ model: String) -> Bool {
        model
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .contains("moonshine")
    }

    static func configuredGenericCommand(command: [String]) -> [String] {
        guard shouldEnablePersistentWorker(command: command) else {
            return command
        }

        if command.contains("--server") {
            return command
        }
        return command + ["--server"]
    }

    private static func shouldEnablePersistentWorker(command: [String]) -> Bool {
        guard isAppleSilicon() else {
            return false
        }
        return command.contains { component in
            component
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .contains("hf_asr_transcribe.py")
        }
    }

    static func isAppleSilicon() -> Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }
}
