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
            return GenericProcessASREngine(
                command: command,
                model: model,
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
}
