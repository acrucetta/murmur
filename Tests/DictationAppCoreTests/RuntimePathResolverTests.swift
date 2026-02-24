import Testing
@testable import DictationAppCore

struct RuntimePathResolverTests {
    @Test
    func prefersExplicitPythonOverride() {
        let resolved = RuntimePathResolver.resolvePythonBinary(
            explicit: "/custom/python3",
            currentDirectory: "/repo",
            environment: [:],
            isExecutable: { _ in false }
        )

        #expect(resolved == "/custom/python3")
    }

    @Test
    func prefersEnvironmentPythonOverrideWhenExplicitMissing() {
        let resolved = RuntimePathResolver.resolvePythonBinary(
            explicit: nil,
            currentDirectory: "/repo",
            environment: ["MURMUR_MOONSHINE_PYTHON": "/env/python3"],
            isExecutable: { _ in false }
        )

        #expect(resolved == "/env/python3")
    }

    @Test
    func prefersASREnvironmentPythonOverride() {
        let resolved = RuntimePathResolver.resolvePythonBinary(
            explicit: nil,
            currentDirectory: "/repo",
            environment: [
                "MURMUR_ASR_PYTHON": "/env/asr-python3",
                "MURMUR_MOONSHINE_PYTHON": "/env/moonshine-python3"
            ],
            isExecutable: { _ in false }
        )

        #expect(resolved == "/env/asr-python3")
    }

    @Test
    func resolvesProjectVenvPythonWhenPresent() {
        let resolved = RuntimePathResolver.resolvePythonBinary(
            explicit: nil,
            currentDirectory: "/repo",
            environment: [:],
            isExecutable: { path in path == "/repo/.venv/bin/python3" }
        )

        #expect(resolved == "/repo/.venv/bin/python3")
    }

    @Test
    func fallsBackToSystemPythonWhenNoOverrides() {
        let resolved = RuntimePathResolver.resolvePythonBinary(
            explicit: nil,
            currentDirectory: "/repo",
            environment: [:],
            isExecutable: { _ in false }
        )

        #expect(resolved == "python3")
    }

    @Test
    func prefersLocalScriptPathWhenPresent() {
        let resolved = RuntimePathResolver.resolveASRScriptPath(
            explicit: nil,
            currentDirectory: "/repo",
            environment: [:],
            fileExists: { path in path == "/repo/scripts/moonshine_transcribe.py" }
        )

        #expect(resolved == "/repo/scripts/moonshine_transcribe.py")
    }

    @Test
    func supportsScriptEnvironmentOverride() {
        let resolved = RuntimePathResolver.resolveASRScriptPath(
            explicit: nil,
            currentDirectory: "/repo",
            environment: ["MURMUR_MOONSHINE_SCRIPT": "/env/script.py"],
            fileExists: { _ in false }
        )

        #expect(resolved == "/env/script.py")
    }

    @Test
    func supportsASRScriptEnvironmentOverride() {
        let resolved = RuntimePathResolver.resolveASRScriptPath(
            explicit: nil,
            currentDirectory: "/repo",
            environment: [
                "MURMUR_ASR_SCRIPT": "/env/asr_script.py",
                "MURMUR_MOONSHINE_SCRIPT": "/env/moonshine_script.py"
            ],
            fileExists: { _ in false }
        )

        #expect(resolved == "/env/asr_script.py")
    }
}
