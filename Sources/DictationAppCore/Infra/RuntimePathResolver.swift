import Foundation

public enum RuntimePathResolver {
    public static func resolvePythonBinary(
        explicit: String?,
        currentDirectory: String,
        environment: [String: String],
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String {
        if let explicit, let trimmed = trimmedValue(explicit) {
            return trimmed
        }

        if let environmentOverride = trimmedValue(environment["MURMUR_ASR_PYTHON"]) {
            return environmentOverride
        }

        if let environmentOverride = trimmedValue(environment["MURMUR_MOONSHINE_PYTHON"]) {
            return environmentOverride
        }

        if let virtualEnv = trimmedValue(environment["VIRTUAL_ENV"]) {
            let virtualEnvPython = "\(virtualEnv)/bin/python3"
            if isExecutable(virtualEnvPython) {
                return virtualEnvPython
            }
        }

        let projectVenvPython = "\(currentDirectory)/.venv/bin/python3"
        if isExecutable(projectVenvPython) {
            return projectVenvPython
        }

        return "python3"
    }

    public static func resolveASRScriptPath(
        explicit: String?,
        currentDirectory: String,
        environment: [String: String],
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> String {
        if let explicit, let trimmed = trimmedValue(explicit) {
            return trimmed
        }

        if let environmentOverride = trimmedValue(environment["MURMUR_ASR_SCRIPT"]) {
            return environmentOverride
        }

        if let environmentOverride = trimmedValue(environment["MURMUR_MOONSHINE_SCRIPT"]) {
            return environmentOverride
        }

        let localScript = "\(currentDirectory)/scripts/moonshine_transcribe.py"
        if fileExists(localScript) {
            return localScript
        }

        return "scripts/moonshine_transcribe.py"
    }

    private static func trimmedValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
